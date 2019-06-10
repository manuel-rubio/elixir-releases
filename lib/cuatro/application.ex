defmodule Cuatro.Application do
  use Application
  require Logger

  @port 1234
  @family :inet

  def children do
    import Supervisor.Spec

    port = Application.get_env(:cuatro, :port, @port)
    family = Application.get_env(:cuatro, :family, @family)

    [{Registry, [keys: :unique, name: Cuatro.Registry]},
     {Cuatro.Http, [port, family]},
     supervisor(Cuatro.Repo, [])]
  end

  def start(_type, _args) do
    {:ok, _} = EctoBootMigration.migrate(:cuatro)

    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def upgrade do
    Supervisor.start_child Cuatro.Supervisor,
                           Supervisor.Spec.supervisor(Cuatro.Repo, [])

    # Create database
    Cuatro.Repo.__adapter__.storage_up(Cuatro.Repo.config())

    # Run migrations
    {:ok, _} = EctoBootMigration.migrate(:cuatro)
  end
end
