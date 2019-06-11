defmodule Cuatro.Application do
  use Application
  require Logger

  @port 1234
  @family :inet

  def children do
    port = Application.get_env(:cuatro, :port, @port)
    family = Application.get_env(:cuatro, :family, @family)

    [{Registry, [keys: :unique, name: Cuatro.Registry]},
     {Cuatro.Http, [port, family]},
     {DynamicSupervisor, strategy: :one_for_one, name: Cuatro.Juegos}]
  end

  def start(_type, _args) do
    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children(), opts)
  end
end
