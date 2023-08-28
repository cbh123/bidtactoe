defmodule Toe.Games.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :slug, :string
    field :scores, :map, default: %{}
    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:slug, :scores])
    |> validate_required([:slug])
  end
end
