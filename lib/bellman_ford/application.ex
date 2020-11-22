defmodule BellmanFord.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @neighbor_names [
    :black,
    :blue,
    :green,
    :orange,
    :red,
    :white,
    :yellow
  ]

  @impl true
  def start(_type, _args) do
    children = [
      {BellmanFord.RouterSupervisor, @neighbor_names}
    ]

    opts = [strategy: :one_for_one, name: BellmanFord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
