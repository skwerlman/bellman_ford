defmodule BellmanFord.RouterSupervisor do
  use Supervisor

  def start_link(x) do
    Supervisor.start_link(__MODULE__, x, name: __MODULE__)
  end

  def init(neighbor_names) do
    children =
      neighbor_names
      |> Enum.map(&node(&1, neighbor_names))

    Supervisor.init(children, strategy: :one_for_one)
  end

  def node(node_name, neighbor_names) do
    neighbors =
      neighbor_names
      |> Stream.filter(fn name -> node_name != name end)
      |> Enum.take_random(:rand.uniform(3))
      |> Enum.map(fn name -> {name, :rand.uniform(10)} end)

    [start_delay] = Enum.take_random(10..100, 1)

    Supervisor.child_spec({BellmanFord.Router, {node_name, neighbors, start_delay}}, id: node_name)
  end
end
