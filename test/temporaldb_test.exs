Code.require_file "test_helper.exs", __DIR__

defmodule TemporalDBTest do
  use ExUnit.Case

  @tdbroot Path.expand __DIR__

  setup_all    do: File.rm_rf(Path.join(@tdbroot, "testdb"))
  teardown_all do: File.rm_rf(Path.join(@tdbroot, "testdb"))

  test "creates, opens, & closes db" do
    tdbloc     = Path.join @tdbroot, "testdb"
    refute       File.exists?(tdbloc)
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    assert       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
    :ok        = tdb|>TemporalDB.close
    refute       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
  end

  test "destroys the database" do
    tdbloc     = Path.join @tdbroot, "testdb"
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    :ok        = tdb|>TemporalDB.destroy
    refute       File.exists?(tdbloc)
  end

  test "that test env default db location is correct" do
    tdbloc     = Path.join @tdbroot, "testdb"
    File.rm_rf(tdbloc)

    refute       File.exists?(tdbloc)
    {:ok, tdb} = TemporalDB.open(:testdb)
    assert       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
    :ok        = tdb|>TemporalDB.destroy
    refute       Process.alive?(tdb)
    refute       File.exists?(tdbloc)
  end

  test "gets info about db server" do
    {:ok, tdb} = TemporalDB.open(:testdb)
    info       = tdb|>TemporalDB.info
    assert       is_tuple(info)
    :ok        = tdb|>TemporalDB.close
  end

  test "saves temporal records" do

    assert false
  end

  test "persists temporal records" do
    assert false
  end

end
