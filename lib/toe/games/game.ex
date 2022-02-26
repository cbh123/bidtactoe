defmodule Toe.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  schema "game" do
    field :slug, :string
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
  end
end
