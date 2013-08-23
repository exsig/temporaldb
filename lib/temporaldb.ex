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

  def close(srv) do
    try do
        :gen_server.call(srv, :close, :infinity)
    catch
        :exit, {:noproc,_}  -> :ok
        :exit, :noproc      -> :ok
        :exit, {:normal, _} -> :ok
    end
  end

  def destroy(srv) do
    try do
        :gen_server.call(srv, :destroy, :infinity)
    catch
        :exit, {:noproc,_}  -> :ok
        :exit, :noproc      -> :ok
        :exit, {:normal, _} -> :ok
    end
  end

  def info(srv),                                 do: :gen_server.call(srv, :info)
  def put(srv, ts, record) when is_list(record), do: :gen_server.cast(srv, {:put, microtime(ts), record})
  def stream_from(srv, ts),                      do: :gen_server.call(srv, {:stream_from, microtime(ts)})



  @doc "64-bit (native-endian) binary representation of the microtime, from various formats"
  def microtime({mega, secs, micro}),                    do: <<(mega * 1_000_000_000_000 + secs * 1_000_000 + micro)::64>>
  def microtime(ts=<<t::64>>),                           do: ts
  def microtime(ts) when is_binary(ts),                  do: microtime(ts|>String.to_float|>elem(0))
  def microtime(ts) when is_integer(ts) and ts < 1.0e10, do: <<(ts * 1_000_000)::64>>
  def microtime(ts) when is_integer(ts),                 do: <<ts::64>>
  def microtime(ts) when is_float(ts) and ts < 1.0e10,   do: <<(round(ts*1_000_000))::64>>
  def microtime(ts) when is_float(ts),                   do: <<(round(ts))::64>>

  #------------------------ General genserver Implementation -----------------------------------------------------------
  defmodule GenServer do
    use Elixir.GenServer.Behaviour

    @default_rootdir      "/srv/exs/streams"
    defrecordp :tdb_state, hdb: nil, root_dir: nil, name: nil, canonical: nil, opts: [], path: nil

    def init({name,opts}) do
      root_dir = opts |> Dict.get(:data_root_dir, @default_rootdir)
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
      {:ok, tdb_state(hdb: db, root_dir: root_dir, name: name, canonical: canonical, opts: opts, path: dir)}
    end

    def handle_call(:close, _from, state), do: {:stop, :normal, :ok, state}
    def handle_call(:destroy, _from, state) do
      res = :hanoidb.destroy(state|>tdb_state(:hdb))
      File.rmdir(state|>tdb_state(:path))
      {:stop, :normal, res, state}
    end
    def handle_call(:info, _from, state), do: {:reply, state, state}
    def handle_call({:stream_from, ts}, _, state) do
      {:reply, :gen_server.start_link(TemporalDB.Stream.GenServer,
               {ts, state|>tdb_state(:hdb), state|>tdb_state(:opts)}, []), state}
    end
    def handle_cast({:put, ts, record}, _, tdb_state(hdb: hdb) = state) do
      :ok = :hanoidb.put(hdb, ts, term_to_binary(record))
      {:noreply, state}
    end
  end

  defmodule Stream do
    def next(str, timeout // :infinity), do: :gen_server.call(str, {:next, timeout})

    defmodule GenServer do
      use Elixir.GenServer.Behaviour
      @historical_at_a_time 10
      defrecordp :stream_state, hdb: nil, queue: [{<<123>>,"test"},{<<124>>,"test2"}], next_ts: <<>>, last_res: nil
      #def init({ts,[canonical: _, hdb: hdb]}), do: {:ok, stream_state(db: db, next_ts: ts)}
      def init({ts,hdb,_opts}), do: {:ok, stream_state(hdb: hdb, next_ts: ts)}

      def handle_call({:next, timeout}, _from_, stream_state(queue: []) = state) do

        {:reply, :empty, state}
      end
      def handle_call({:next, timeout}, _from_, stream_state(queue: [curr|tail]) = state) do

        {:reply, curr, stream_state(state, queue: tail)}
      end
    end
  end
end
