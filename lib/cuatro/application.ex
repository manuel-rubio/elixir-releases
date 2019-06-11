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
    {:ok, _} = EctoBootMigration.migrate(:cuatro)

    Logger.info "[app] app initiated"

    opts = [strategy: :one_for_one, name: Cuatro.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  def upgrade do
    IO.puts "==> Updating supervisor (add Cuatro.Repo)"
    Supervisor.start_child Cuatro.Supervisor,
                           Supervisor.Spec.supervisor(Cuatro.Repo, [])

    # Config environment
    System.put_env "MNESIA_HOST", to_string(node())
    File.mkdir_p! Application.get_env(:mnesia, :dir)
    
    # Create database
    IO.puts "==> Updating database (create database) #{node()}"
    Cuatro.Repo.__adapter__.storage_down(Cuatro.Repo.config())
    Cuatro.Repo.__adapter__.storage_up(Cuatro.Repo.config())

    # Run migrations
    IO.puts "==> Running Migrations"
    {:ok, _} = EctoBootMigration.migrate(:cuatro)
  end
end
