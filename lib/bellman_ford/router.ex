defmodule BellmanFord.Router do
  use GenServer
  require Logger

  @type neighbor :: {id :: atom, cost :: integer}

  @announce_delay 60_000

  @impl GenServer
  @spec init({node_name :: atom, neighbors, start_delay :: integer}) ::
          {:ok, {neighbors, ping_timer :: reference}}
        when neighbors: nonempty_list(neighbor)
  def init({node_name, neighbors, start_delay}) do
    Process.register(self(), node_name)
    info("Router starting...")
    debug("starting routes: #{inspect(neighbors)}")
    ping_timer = Process.send_after(self(), :ANNOUNCE, start_delay)
    {:ok, {neighbors, ping_timer}}
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def handle_info(:ANNOUNCE, {neighbors, ping_timer}) do
    info("Announcing our routing table")
    _ = Process.cancel_timer(ping_timer)

    me = name()

    for {node, _} <- neighbors do
      send(node, {:ROUTING_UPDATE, me, neighbors})
    end

    {:noreply, {neighbors, Process.send_after(self(), :ANNOUNCE, @announce_delay)}}
  end

  def handle_info({:ROUTING_UPDATE, from, routes}, {neighbors, ping_timer}) do
    info("Got routing table update...")
    debug("got #{inspect(routes)} from #{inspect(from)}")

    me = name()
    from_cost = cost_of(from, neighbors)

    # correct the cost of the advertised routes, and remove references to us
    relevent_routes =
      routes
      |> Stream.filter(fn {name, _} -> name != me end)
      |> Enum.map(fn {name, cost} -> {name, cost + from_cost} end)

    # merge the new routes into our current routing table
    new_neighbors =
      relevent_routes
      |> (&++/2).(neighbors)
      # sort alphabetically by name
      |> Enum.sort_by(fn {name, _cost} -> to_string(name) end)
      |> Enum.reduce(
        [],
        fn
          # if the name of the previous route is ours, and our cost is better
          {name, cost} = route, [{newest_name, newest_cost} | rest]
          when name == newest_name and cost < newest_cost ->
            # use our route, replacing theirs
            [route | rest]

          # if the name of the previous route is ours, but their cost is the same or better
          {name, _}, [{newest_name, _} | _] = acc when name == newest_name ->
            # make no changes
            acc

          # if the name of the previous route differs
          route, acc ->
            # use our route
            [route | acc]
        end
      )

    # check if our routes have changed; if so, :ANNOUNCE them
    if new_neighbors -- neighbors != [] do
      info("Routing table changed!")
      send(self(), :ANNOUNCE)
    end

    debug("num routes: #{length(new_neighbors)}, prev: #{length(neighbors)}")

    {:noreply, {new_neighbors, ping_timer}}
  end

  defp cost_of(name, neighbors) do
    neighbors
    |> Enum.filter(fn {n, _} -> n == name end)
    |> Enum.reduce(0, fn x, acc -> min(x, acc) end)
  end

  defp info(msg) do
    Logger.info("[#{name()}] " <> msg)
  end

  defp debug(msg) do
    Logger.debug("[#{name()}] " <> msg)
  end

  defp error(msg) do
    Logger.error("[#{name()}] " <> msg)
  end

  defp name() do
    self()
    |> Process.info(:registered_name)
    |> elem(1)
  end
end
