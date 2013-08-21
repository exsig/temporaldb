Code.require_file "test_helper.exs", __DIR__

defmodule TemporalDBTest do
  use ExUnit.Case

  setup do
    IO.puts "Setting up..."
    :ok
  end

  test "the truth" do
    assert(true)
  end

  test "another truth" do
    assert(true)
  end

end
