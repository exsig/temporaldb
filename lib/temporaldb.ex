
defrecord TDB, [:srv, :name] do
  record_type srv: pid, name: String.t | nil
end


defmodule TemporalDB do


  @moduledoc """
    * Each stream has two channels:
      - data-stream
      - meta-data-stream
         - For defining when gaps start and end
         - For defining other sparse state information about the data-stream
    
    * Open: opens or creates a new stream-pair, starts up temporaldb and gives back {:ok,PID} (and possibly can register
          name like a gen_server).

    * Separate live-fill and back-fill servers.

    * Ideally some sort of simple visualization tool (to calculate things like %-filled, rates, etc.)

    * The following attributes by default:
      - (key) Canonical timestamp
      - Intrinsic monotonic id?? (maybe not stored but built into stream feeder?)
      - Live receipt timestamp
        - (and therefore connectivity-latency)
        - (needs to be modeled for backfill)



    NEED OUTPUT STREAMS TO BE COMPOSABLE


    Difficult / unsolved:
      - Backlog on historical feed
      - Seemless transition from historical to live (probably "live" needs to be able to hand out the "last 3 values" or something)

    TODO:
      - 
  """


  def open_registered(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start({:local,name}, TemporalDB.GenServer, {name, options}, start_opts)
  end

  def open_registered_link(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start_link({:local,name}, TemporalDB.GenServer, {name, options}, start_opts)
  end

  def open(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start(TemporalDB.GenServer, {name, options}, start_opts)
  end

  def open_link(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start_link(TemporalDB.GenServer, {name, options}, start_opts)
  end

  #@spec close(TDB.t) :: :ok
  def close(srv) do
    try do
        :gen_server.call(srv, :close, :infinity)
    catch
        :exit, {:noproc,_}  -> :ok
        :exit, :noproc      -> :ok
        :exit, {:normal, _} -> :ok
    end
  end

  #@spec destroy(TDB.t) :: :ok | {:error, :noproc}
  def destroy(srv) do
    try do
        :gen_server.call(srv, :destroy, :infinity)
    catch
        :exit, {:noproc,_}  -> {:error, :noproc}
        :exit, :noproc      -> {:error, :noproc}
        :exit, {:normal, _} -> :ok
    end
  end

  def info(srv),             do: :gen_server.call(srv, :info)

  def put!(srv, ts, record), do: :gen_server.call(srv, {:put,         Time.microtime64(ts), term_to_binary(record)})
  def put(srv, ts, record),  do: :gen_server.cast(srv, {:put_async,   Time.microtime64(ts), term_to_binary(record)})

  def get(srv, ts),          do: :gen_server.call(srv, {:get,         Time.microtime64(ts)})
  def stream_from(srv, ts),  do: :gen_server.call(srv, {:stream_from, Time.microtime64(ts)})

  def fold(srv, acc0, fun),  do: :gen_server.call(srv, {:fold, acc0, fun})
  def to_list(srv),          do: :gen_server.call(srv, :to_list)


  #------------------------ General genserver Implementation -----------------------------------------------------------
  defmodule GenServer do
    use Elixir.GenServer.Behaviour

    defrecordp :tState, hdb: nil, root_dir: nil, name: nil, canonical: nil, opts: [], path: nil

    defp data_root_dir([]) do
      case System.get_env("TDB_ROOTDIR") do
        nil ->
          _ = Mix.start()
          Mix.Project.config[:default_root_dir] || System.cwd
        from_env -> from_env
      end
    end
    defp data_root_dir([{:data_root_dir,v}|_]), do: v
    defp data_root_dir([_|tail]), do: data_root_dir(tail)

    def init({name,opts}) do
      root_dir = data_root_dir(opts)
      :ok = File.mkdir_p(root_dir)
      dir = "#{root_dir}/#{name}"
      canonical = "#{node()}:#{dir}" |> Kernel.binary_to_atom
      {:ok, db} = case :hanoidb.open_link({:global,canonical}, dir |> String.to_char_list!,
                                          compress:       :snappy,
                                          merge_strategy: :fast,
                                          sync_strategy:  {:seconds, 15}) do
                    {:ok, server} -> {:ok, server}
                    {:error, {:already_started, server}} -> {:ok, server}
                  end
      {:ok, tState(hdb: db, root_dir: root_dir, name: name, canonical: canonical, opts: opts, path: dir)}
    end

    def handle_call(:close, _from, tState(hdb: hdb) = st) do
      if is_pid(hdb) and Process.alive?(hdb) do
        {:links, links} = Process.info(hdb,:links)
        if length(links) <= 3, do: :hanoidb.close(hdb)
      end
      {:stop, :normal, :ok, st}
    end

    def handle_call(:destroy, _from, tState(hdb: hdb, path: path) = st) do
      res = :hanoidb.destroy(hdb)
      File.rm_rf(path)
      :hanoidb.close(hdb)
      {:stop, :normal, res, st}
    end

    def handle_call(:info, _from, st), do: {:reply, st, st}
    def handle_call({:put, ts, record},_,tState(hdb: hdb)=st), do: {:reply, :hanoidb.put(hdb, ts, record), st}
    def handle_call({:stream_from, ts},_,tState(hdb: hdb)=st), do: {:reply,:gen_server.start_link(TemporalDB.Stream.GenServer, {ts,hdb,tState(st,:opts)},[]), st}
    def handle_call({:get, ts},_,tState(hdb: hdb)=st) do
      case :hanoidb.get(hdb, ts) do
        {:ok, btrm} when is_binary(btrm) -> {:reply, {:ok, binary_to_term(btrm)}, st}
        other ->                            {:reply, other, st}
      end
    end

    def handle_call({:fold,acc0,fun},_,tState(hdb: hdb)=st), do: {:reply, :hanoidb.fold(hdb, fun, acc0), st}
    def handle_call(:to_list,_,tState(hdb: hdb)=st) do
      {:reply, :hanoidb.fold(hdb,fn(k,v,acc)-><<k::64>>=k; [{k,binary_to_term(v)}|acc] end, []) |> :lists.reverse, st}
    end

    def handle_cast({:put_async, ts, record}, _, tState(hdb: hdb) = st) do
      :ok = :hanoidb.put(hdb, ts, record)
      {:noreply, st}
    end
  end

  defmodule Stream do
    def next(str, timeout // :infinity), do: :gen_server.call(str, {:next, timeout})

    defmodule GenServer do
      use Elixir.GenServer.Behaviour
      @historical_at_a_time 10
      defrecordp :strState, hdb: nil, queue: [], next_ts: <<>>, last_res: nil

      def init({ts,hdb,_opts}), do: {:ok, strState(hdb: hdb, next_ts: ts)}

      def handle_call({:next, timeout}, from, strState(hdb: hdb, queue: [], next_ts: ts) = st) do
        {ts, queue} = next_n(hdb, ts, 100)
        if queue == [] do
          {ts, queue} = next_n(hdb, ts, 9) # Fewer in the request has chance to pick up fresher data
          if queue == [] do
            # TODO: receive messages as appropriate to try to get the next one
            {:reply, :empty, st}
          else
            handle_call({:next, timeout}, from, strState(st, queue: queue, next_ts: ts))
          end
        else
          handle_call({:next, timeout}, from, strState(st, queue: queue, next_ts: ts))
        end
      end

      def handle_call({:next, _timeout}, _from, strState(queue: [curr|tail]) = st), do: {:reply, curr, strState(st, queue: tail)}

      defp next_n(hdb, gt_ts, n) do
        res = :hanoidb.fold_range(hdb, fn(k,v,acc)->[{k,binary_to_term(v)}|acc] end, [],
          {:key_range, gt_ts, false, :undefined, false, n})
        case res do
          [{k,_v}|_] -> {k, res |> Enum.reduce [], fn({k2,v},acc)-><<k3::64>>=k2; [{k3,v}|acc] end}
          [] -> {gt_ts, []}
        end
      end
    end
  end
end
