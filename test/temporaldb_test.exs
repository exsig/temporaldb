Code.require_file "test_helper.exs", __DIR__

defmodule TemporalDBTest do
  use ExUnit.Case, async: true

  @tdbroot Path.expand __DIR__

  test "creates, opens, & closes db" do
    tdbloc = Path.join @tdbroot, "testdb"
    File.rm_rf tdbloc

    refute       File.exists?(tdbloc)
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    assert       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
    :ok        = tdb|>TemporalDB.close
    refute       Process.alive?(tdb)
    assert       File.exists?(tdbloc)
  end

  test "destroys the database" do
    tdbloc = Path.join @tdbroot, "testdb"
    {:ok, tdb} = TemporalDB.open(:testdb, data_root_dir: @tdbroot)
    :ok        = tdb|>TemporalDB.destroy
    refute       File.exists?(tdbloc)
  end

  test "saves temporal records" do

  end

  test "persists temporal records" do
    assert(true)
  end

end
