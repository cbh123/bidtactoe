defmodule Toe.Repo do
  use Ecto.Repo,
    otp_app: :toe,
    adapter: Ecto.Adapters.Postgres
end
