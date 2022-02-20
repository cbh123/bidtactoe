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
  checks. You also can't bid when we're not in selecting mode,
  hence the status guard.

  Then returns the %Game{} struct.
  """
  def declare_selected_square(
        %Game{board: board, status: :selecting} = game,
        selected_square
      ) do
    board =
      Enum.map(board, fn sq ->
        if sq.name == selected_square and can_square_be_selected?(sq),
          do: %{sq | selected: true},
          else: sq
      end)

    game
    |> update_status_log("#{who_declared_status?(game).name} selected: #{selected_square}")
    |> next_turn()
    |> save_game(%{board: board, status: :bidding})
  end

  def submit_bid(%Game{players: players} = game, player, bid) do
    players =
      Enum.map(players, fn p ->
        if p.name == player.name,
          do: %{p | bid: String.to_integer(bid)},
          else: p
      end)

    game
    |> Map.merge(%{players: players})
    |> update_status_log("#{player.name} bid: #{bid}")
    |> check_bid_outcome()
    |> save_game()
  end

  defp check_bid_outcome(%Game{} = game) do
    if all_players_bid?(game) do
      bid_outcome(game)
    else
      game
    end
  end

  defp bid_outcome(%Game{} = game) do
    """
    # if there's a tie, reset bids to zero, status stays at bidding
    # if someone won the bid:
    - change the board to their letter
    - subtract both the bids from the players
    - check if there's a winner
      - if there is, game over!
      - if not:
        - change status to selecting
        - change all bids to nil
    """

    if any_ties?(game) do
      game
      |> set_all_bids_to_nil()
      |> update_status_log("Bids are tied, bid again")
    else
      max_bid = Enum.max(Enum.map(game.players, fn p -> p.bid end))
      winner = Enum.find(game.players, fn p -> p.bid == max_bid end)

      game
      |> subtract_bids()
      |> set_all_bids_to_nil()
      |> set_selections_to_nil()
      |> set_status(:selecting)
      |> set_square_letter(get_selected_square(game), winner.letter)
      |> update_status_log("#{winner.name} wins the bid with #{max_bid}")
      |> check_for_win(winner)
    end
  end

  defp any_ties?(%Game{players: players}) do
    bids = Enum.map(players, fn p -> p.bid end)
    Enum.uniq(bids) != bids
  end

  defp set_all_bids_to_nil(%Game{players: players} = game) do
    players = Enum.map(players, fn p -> %{p | bid: nil} end)
    Map.merge(game, %{players: players})
  end

  defp set_selections_to_nil(%Game{board: board} = game) do
    board = Enum.map(board, fn sq -> %{sq | selected: false} end)
    Map.merge(game, %{board: board})
  end

  defp next_turn(%Game{} = game) do
    Map.merge(game, %{player_turn: next_player_turn(game)})
  end

  defp set_status(%Game{} = game, status) when status in [:selecting, :bidding, :done] do
    Map.merge(game, %{status: status})
  end

  defp set_square_letter(%Game{board: board} = game, %Square{name: name}, letter) do
    board =
      Enum.map(board, fn sq ->
        if sq.name == name,
          do: %{sq | letter: letter},
          else: sq
      end)

    Map.merge(game, %{board: board})
  end

  defp get_selected_square(%Game{board: board}) do
    Enum.find(board, fn sq -> sq.selected end)
  end

  defp all_players_bid?(%Game{players: players}) do
    Enum.all?(players, fn p -> p.bid end)
  end

  defp subtract_bids(%Game{players: players} = game) do
    players = Enum.map(players, fn p -> %{p | points: p.points - p.bid} end)
    Map.merge(game, %{players: players})
  end

  @doc """
  Checks if a player has bid already in this bidding round.
  """
  def has_bid_already?(%Game{players: players}, player) do
    Enum.find(players, fn p -> p.name == player.name and p.bid end) != nil
  end

  def current_player_turn(%Game{player_turn: player_turn, players: players}) do
    Enum.at(players, player_turn - 1) |> IO.inspect(label: "turn?")
  end

  defp next_player_turn(%Game{player_turn: player_turn, players: players}) do
    if player_turn + 1 > length(players), do: 1, else: player_turn + 1
  end

  defp can_square_be_selected?(%Square{selected: false}), do: true
  defp can_square_be_selected?(%Square{selected: true}), do: false

  defp who_declared_status?(%Game{
         player_turn: player_turn,
         players: players
       }) do
    Enum.at(players, player_turn - 1)
  end

  @doc """
  Updates the status log with a new status.

  Returns a game.
  """
  def update_status_log(%Game{status_log: status_log} = game, new_status) do
    Map.merge(game, %{status_log: status_log ++ [new_status]})
  end

  def save_game(%Game{} = game, attrs \\ %{}) do
    game =
      game
      |> Map.merge(attrs)

    broadcast({:ok, game}, :game_updated, game.slug)
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

  def subscribe(slug) do
    Phoenix.PubSub.subscribe(Toe.PubSub, "room:" <> slug)
  end

  defp broadcast({:error, _reason} = error, _event, _slug), do: error

  defp broadcast({:ok, game}, event, slug) do
    Phoenix.PubSub.broadcast(Toe.PubSub, "room:" <> slug, {event, game})
    {:ok, game}
  end

  defp check_for_win(%Game{} = game, %Player{} = player) do
    case _check_for_win(game, player) do
      :not_found ->
        game

      [sq1, sq2, sq3] ->
        game
        |> Map.merge(%{winning_squares: [sq1, sq2, sq3]})
        |> set_status(:done)
        |> update_status_log("#{player.name} won the game!")
    end
  end

  @doc """
  Check to see if the player won. Return a tuple of the winning squares if the they won. If no win found, returns `:not_found`.
  Tests for all the different ways the player could win.
  """
  defp _check_for_win(%Game{board: board}, %Player{letter: letter}) do
    case board do
      #
      # Check for all the straight across wins
      [%Square{letter: ^letter}, %Square{letter: ^letter}, %Square{letter: ^letter} | _] ->
        [:sq11, :sq12, :sq13]

      [_, _, _, %Square{letter: ^letter}, %Square{letter: ^letter}, %Square{letter: ^letter} | _] ->
        [:sq21, :sq22, :sq23]

      [
        _,
        _,
        _,
        _,
        _,
        _,
        %Square{letter: ^letter},
        %Square{letter: ^letter},
        %Square{letter: ^letter}
      ] ->
        [:sq31, :sq32, :sq33]

      #
      # Check for all the vertical wins
      [
        %Square{letter: ^letter},
        _,
        _,
        %Square{letter: ^letter},
        _,
        _,
        %Square{letter: ^letter},
        _,
        _ | _
      ] ->
        [:sq11, :sq21, :sq31]

      [
        _,
        %Square{letter: ^letter},
        _,
        _,
        %Square{letter: ^letter},
        _,
        _,
        %Square{letter: ^letter},
        _ | _
      ] ->
        [:sq12, :sq22, :sq32]

      [
        _,
        _,
        %Square{letter: ^letter},
        _,
        _,
        %Square{letter: ^letter},
        _,
        _,
        %Square{letter: ^letter} | _
      ] ->
        [:sq13, :sq23, :sq33]

      #
      # Check for the diagonal wins
      [
        %Square{letter: ^letter},
        _,
        _,
        _,
        %Square{letter: ^letter},
        _,
        _,
        _,
        %Square{letter: ^letter} | _
      ] ->
        [:sq11, :sq22, :sq33]

      [
        _,
        _,
        %Square{letter: ^letter},
        _,
        %Square{letter: ^letter},
        _,
        %Square{letter: ^letter},
        _,
        _ | _
      ] ->
        [:sq13, :sq22, :sq31]

      _ ->
        :not_found
    end
  end
end
