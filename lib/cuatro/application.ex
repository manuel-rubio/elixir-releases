defmodule Cuatro.Application do
  use Application
  require Logger

  def start(_type, _args) do
    children = [
      Cuatro.Juego,
    ]

    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
