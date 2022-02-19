defmodule Toe.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Toe.Repo

  alias Toe.Games.Game
  alias Toe.Games.Square
  alias Toe.Games.Player

  @doc """
  Declares that a selected_square in the game is "selected",
  meaning that it's up for bidding.

  You can't select a square that already has a letter, so it
  checks. You also can't bid when we're not in bidding mode,
  hence the status guard.

  Then returns the %Game{} struct.
  """
  def declare_selected_square(
        %Game{board: board, status: :bidding} = game,
        selected_square
      ) do
    board =
      Enum.map(board, fn sq ->
        if sq.name == selected_square and can_square_be_selected?(sq),
          do: %{sq | selected: true},
          else: sq
      end)

    game
    |> update_status_log("#{who_declared_status?(game)} selected: #{selected_square}")
    |> update_game(%{board: board, player_turn: next_player(game)})
  end

  defp next_player(%Game{player_turn: 1}), do: 2
  defp next_player(%Game{player_turn: 2}), do: 1

  defp can_square_be_selected?(%Square{selected: false}), do: true
  defp can_square_be_selected?(%Square{selected: true}), do: false

  defp who_declared_status?(%Game{
         player_turn: player_turn,
         player1: %Player{name: name1},
         player2: %Player{name: name2}
       }) do
    if player_turn == 1, do: name1, else: name2
  end

  @doc """
  Updates the status log with a new status.

  Returns a game.
  """

  def update_status_log(%Game{status_log: status_log} = game, new_status) do
    update_game(game, %{status_log: status_log ++ [new_status]})
  end

  def update_game(%Game{} = game, attrs) do
    Map.merge(game, attrs)
  end

  @doc """
  Returns the list of game.

  ## Examples

      iex> list_game()
      [%Game{}, ...]

  """
  def list_game do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id)

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end
end
