Code.require_file "test_helper.exs", __DIR__

defmodule TemporalDBTest do
  use ExUnit.Case, async: true

  @tdbroot Path.expand __DIR__

  setup_all    do: File.rm_rf(Path.join(@tdbroot, "testdb"))
  teardown_all do: File.rm_rf(Path.join(@tdbroot, "testdb"))

  test "creates, opens, & closes db" do
    tdbloc     = Path.join @tdbroot, "testdb"
    refute       File.exists?(tdbloc)
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    assert       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
    :ok        = TemporalDB.close(tdb)
    refute       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
  end

  test "destroys the database" do
    tdbloc     = Path.join @tdbroot, "testdb"
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    :ok        = TemporalDB.destroy(tdb)
    refute       Process.alive?(tdb)
    refute       File.exists?(tdbloc)
  end

  test "gets info about db server" do
    {:ok, tdb} = TemporalDB.open(:testdb)
    info       = TemporalDB.info(tdb)
    assert       is_tuple(info)
    assert :ok = TemporalDB.close(tdb)
  end

  test "test-env default db location is correct" do
    tdbloc     = Path.join @tdbroot, "testdb"
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    :ok        = TemporalDB.destroy(tdb)

    refute       File.exists?(tdbloc)
    {:ok, tdb} = TemporalDB.open(:testdb)
    assert       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
    :ok        = TemporalDB.destroy(tdb)
  end

  test "saves temporal records (sync)" do
    {:ok, tdb} = TemporalDB.open :testdb
    ts         = Time.now()
    assert     :ok = TemporalDB.put!(tdb, ts, "saved-dat")
    assert     {:ok,"saved-dat"} = TemporalDB.get(tdb,ts)
  end

  test "persists temporal records" do
    {:ok, tdb} = TemporalDB.open :testdb
    ts         = Time.now()
    assert     :ok = TemporalDB.put!(tdb, ts, "saved-dat")
    :ok        = TemporalDB.close(tdb)
    {:ok, tdb2}= TemporalDB.open :testdb
    {:ok, tdb3}= TemporalDB.open :testdb
    assert     {:ok,"saved-dat"} = TemporalDB.get(tdb2,ts)
    assert     {:ok,"saved-dat"} = TemporalDB.get(tdb3,ts)
    :ok        = TemporalDB.close(tdb2)
    :ok        = TemporalDB.close(tdb3)
  end

  test "replace record" do
    assert false
  end

  test "remove record" do
    assert false
  end

  test "blocking fold over all members" do
    assert false
  end

  test "records stored in correct order" do
    keys = 1..200 |>
      Enum.map fn(_)->
        v=:crypto.rand_bytes(8)
        <<n::64>> = v
        n
      end
    {:ok, tdb} = TemporalDB.open :testdb

    Enum.each keys, fn(k) ->
      :ok = TemporalDB.put!(tdb, k, :crypto.rand_bytes(:random.uniform(50)))
    end
    keys_out = TemporalDB.to_list(tdb) |> Enum.map(fn({k,v}) -> k end)
    assert keys_out = keys |> Enum.sort
    :ok        = TemporalDB.destroy(tdb)
  end

  test "stream from table" do
    assert false
  end

  test "stream from table with simulation base-time" do
    assert false
  end

  test "stream with live-feed" do
    assert false
  end

  test "stream with transition from simulated to live-feed" do
    assert false
  end


end
