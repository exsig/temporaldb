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

end
