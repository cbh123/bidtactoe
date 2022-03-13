defmodule Toe.Games.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    field :status, :string
    belongs_to :game, Toe.Games.Game, references: :slug, foreign_key: :slug, type: :string

    timestamps()
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end
end
