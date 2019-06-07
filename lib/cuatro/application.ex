defmodule Cuatro.Application do
  use Application
  require Logger

  @port 1234
  @family :inet

  def start(_type, _args) do
    port = Application.get_env(:cuatro, :port, @port)
    family = Application.get_env(:cuatro, :family, @family)

    children = [
      {Registry, [keys: :unique, name: Cuatro.Registry]},
      {Cuatro.Http, [port, family]},
    ]

    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
