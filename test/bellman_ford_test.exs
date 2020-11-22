defmodule BellmanFordTest do
  use ExUnit.Case
  doctest BellmanFord

  test "greets the world" do
    assert BellmanFord.hello() == :world
  end
end
