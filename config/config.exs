use Mix.Config

config :cuatro, ecto_repos: [Cuatro.Repo]

config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

config :mnesia, dir: 'priv/data/mnesia' # Make sure this directory exists

config :cuatro, Cuatro.Repo,
  adapter: EctoMnesia.Adapter
