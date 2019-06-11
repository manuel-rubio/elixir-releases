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
     {DynamicSupervisor, strategy: :one_for_one, name: Cuatro.Juegos},
     supervisor(Cuatro.Repo, [])]
  end

  def start(_type, _args) do
    ensure_database_is_up()
    {:ok, _} = EctoBootMigration.migrate(:cuatro)

    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children(), opts)
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
