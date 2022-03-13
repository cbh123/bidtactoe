defmodule Toe.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  schema "game" do
    belongs_to :room, Toe.Games.Room, references: :slug, foreign_key: :slug, type: :string
    field :status, :string
    field :players, {:array, :map}
    field :player_turn, :integer
    field :status_log, {:array, :string}
    field :winning_squares, {:array, :map}
    field :board, {:array, :map}

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [
      :slug,
      :status,
      :players,
      :player_turn,
      :status_log,
      :player_turn,
      :status,
      :board
    ])
    |> unique_constraint(:slug)
  end
end
