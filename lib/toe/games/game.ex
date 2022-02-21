defmodule Toe.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset
  alias Toe.Games.Player
  alias Toe.Games.Square

  defstruct slug: nil,
            status: :selecting,
            players: [],
            # zero-indexed
            player_turn: 0,
            status_log: [],
            winning_squares: [],
            board: [
              # Row 1
              Square.build(:sq11),
              Square.build(:sq12),
              Square.build(:sq13),
              # Row 2
              Square.build(:sq21),
              Square.build(:sq22),
              Square.build(:sq23),
              # Row 3
              Square.build(:sq31),
              Square.build(:sq32),
              Square.build(:sq33)
            ]

  # schema "game" do
  #   field :board, {:array, :string}
  #   field :player1, {:map, :string}
  #   field :player2, {:map, :string}
  #   field :player1_points, :integer
  #   field :player2_points, :integer
  #   field :player_turn, :integer
  #   field :slug, :string
  #   field :status, :string

  #   timestamps()
  # end

  # @doc false
  # def changeset(game, attrs) do
  #   game
  #   |> cast(attrs, [
  #     :slug,
  #     :player1,
  #     :player2,
  #     :player1_points,
  #     :player2_points,
  #     :player_turn,
  #     :status,
  #     :board
  #   ])
  #   |> validate_required([
  #     :slug,
  #     :player1,
  #     :player2,
  #     :player1_points,
  #     :player2_points,
  #     :player_turn,
  #     :status,
  #     :board
  #   ])
  # end
end
