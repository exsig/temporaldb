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

  @default_rootdir "/srv/exs/streams"

  use GenServer.Behaviour

  def open_registered(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start({:local,name}, __MODULE__, {name, options}, start_opts)
  end

  def open_registered_link(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start_link({:local,name}, __MODULE__, {name, options}, start_opts)
  end

  def open(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start(__MODULE__, {name, options}, start_opts)
  end

  def open_link(name, options // []) do
    {start_opts, options} = options |> Dict.pop :start_opts,[]
    :gen_server.start_link(__MODULE__, {name, options}, start_opts)
  end

  def info(srv), do: :gen_server.call(srv,:info)


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
    {:ok, canonical: canonical, db: db}
  end

  def handle_call(:info, _from, state), do: {:reply, state, state}
end

