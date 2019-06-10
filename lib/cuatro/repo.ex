defmodule Cuatro.Repo do
  use Ecto.Repo,
    otp_app: :cuatro,
    adapter: EctoMnesia.Adapter
end
