defmodule Cuatro.Application do
  use Application
  require Logger

  def children do
    import Supervisor.Spec

    [{Registry, [keys: :unique, name: Cuatro.Registry]},
     {Cuatro.Http, []},
     {DynamicSupervisor, strategy: :one_for_one, name: Cuatro.Juegos},
     supervisor(Cuatro.Repo, [])]
  end

  @impl true
  def start(_type, _args) do
    ensure_database_is_up()
    {:ok, _} = EctoBootMigration.migrate(:cuatro)

    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  @impl true
  def config_change(changed, new, removed) do
    if port = changed[:port] do
      Supervisor.terminate_child Cuatro.Supervisor, Cuatro.Http
      :cowboy.stop_listener Cuatro.Http
      Supervisor.restart_child Cuatro.Supervisor, Cuatro.Http
    end
  end

  defp ensure_database_is_up do
    # Config environment
    System.put_env "MNESIA_HOST", to_string(node())
    File.mkdir_p! Application.get_env(:mnesia, :dir)

    # Create database
    Cuatro.Repo.__adapter__.storage_up(Cuatro.Repo.config())
  end

  def upgrade do
    File.cp! "lib/cuatro-4.0.0/priv/config.toml", "priv/config.toml"
  end
end
