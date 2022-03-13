defmodule Toe.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Toe.Repo

  alias Toe.Games.{Game, Square, Player, Room}

  def game_over?(%Game{status: "done"}), do: true
  def game_over?(%Game{status: _}), do: false

  @doc """
  Declares that a selected_square in the game is "selected",
  meaning that it's up for bidding.

  You can't select a square that already has a letter, so it
  checks. You also can't bid when we're not in selecting mode,
  hence the status guard.

  Then returns the %Game{} struct.
  """
  def declare_selected_square(
        %Game{board: board, status: "selecting"} = game,
        %Square{name: name}
      ) do
    board =
      Enum.map(board, fn sq ->
        if sq.name == name and can_square_be_selected?(sq),
          do: %{sq | selected: true},
          else: sq
      end)

    game
    |> update_status_log("#{Enum.at(game.players, game.player_turn).name} selected: #{name}")
    |> update_game(%{board: board, status: "bidding"})
  end

  @doc """
  Submits bid when you don't have enough points, which returns error with message.

  Returns {:error, message}
  """
  def submit_bid(%Game{} = game, %Player{points: points}, bid)
      when points < bid and is_number(bid),
      do: {:error, "You don't have enough points!"}

  @doc """
  Submit negative bid, which returns error with message.

  Returns {:error, message}
  """
  def submit_bid(%Game{} = game, %Player{points: points}, bid)
      when is_number(bid) and bid < 0,
      do: {:error, "You can't submit a negative bid!"}

  @doc """
  Submits bid when you DO have enough points. Bid is an int here.

  Returns {:ok, game} if valid, {:error, message} otherwise.
  """
  def submit_bid(%Game{players: players} = game, %Player{points: points, name: name}, bid)
      when points >= bid and is_number(bid) do
    case has_bid_already?(game, name) do
      true ->
        {:error, "You've already bid!"}

      _ ->
        # update players
        players =
          Enum.map(players, fn p ->
            if p.name == name,
              do: %{p | bid: bid},
              else: p
          end)

        {:ok, game} =
          game
          |> update_status_log("#{name} bid: #{bid}")
          |> update_game(%{players: players})

        check_bid_outcome(game)
    end
  end

  defp check_bid_outcome(%Game{} = game) do
    if all_players_bid?(game), do: bid_outcome(game), else: game
  end

  defp bid_outcome(%Game{} = game) do
    """
    if there's a tie, reset bids to zero, status stays at bidding
    if someone won the bid:
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
      bid_winner = Enum.find(game.players, fn p -> p.bid == max_bid end)
      selected_square = get_selected_square(game)

      game
      |> subtract_bids()
      |> set_all_bids_to_nil()
      |> set_selections_to_nil()
      |> set_status("selecting")
      |> set_square_letter(selected_square, bid_winner.letter)
      |> update_status_log("#{bid_winner.name} wins the bid with #{max_bid}")
      |> check_for_win(bid_winner)
      |> next_turn()
    end
  end

  defp any_ties?(%Game{players: players}) do
    bids = Enum.map(players, fn p -> p.bid end)
    Enum.uniq(bids) != bids
  end

  defp set_all_bids_to_nil(%Game{players: players} = game) do
    players = Enum.map(players, fn p -> %{p | bid: nil} end)
    {:ok, game} = update_game(game, %{players: players})
    game
  end

  defp set_selections_to_nil(%Game{board: board} = game) do
    board = Enum.map(board, fn sq -> %{sq | selected: false} end)
    {:ok, game} = update_game(game, %{board: board})
    game
  end

  defp next_turn(%Game{} = game) do
    update_game(game, %{player_turn: next_player_turn(game)})
  end

  defp set_status(%Game{} = game, status)
       when status in ["selecting", "bidding", "done"] do
    {:ok, game} = update_game(game, %{status: status})
    game
  end

  defp set_square_letter(%Game{board: board} = game, %Square{name: name}, letter) do
    board =
      Enum.map(board, fn sq ->
        if sq.name == name,
          do: %{sq | letter: letter},
          else: sq
      end)

    {:ok, game} = update_game(game, %{board: board})
    game
  end

  defp subtract_bids(%Game{players: players} = game) do
    players = Enum.map(players, fn p -> %{p | points: p.points - p.bid} end)
    {:ok, game} = update_game(game, %{players: players})
    game
  end

  defp get_selected_square(%Game{board: board}) do
    Enum.find(board, fn sq -> sq.selected end)
  end

  defp all_players_bid?(%Game{players: players}) do
    Enum.all?(players, fn p -> p.bid end)
  end

  defp all_squares_taken?(board) do
    Enum.all?(board, fn sq -> sq.letter end)
  end

  @doc """
  Checks if a player has bid already in this bidding round.
  """
  def has_bid_already?(%Game{players: players}, username) do
    Enum.find(players, fn p -> p.name == username and p.bid end) != nil
  end

  @doc """
  Get the player whose turn it is.
  """
  def current_player_turn(%Game{player_turn: player_turn, players: players}) do
    Enum.at(players, player_turn)
  end

  defp next_player_turn(%Game{player_turn: player_turn, players: players}) do
    if player_turn >= length(players) - 1, do: 0, else: player_turn + 1
  end

  @doc """
  Lets us know whether a square can be selected for bidding.
  Square can't be selected if it's already selected, or if there's already a letter on it.
  """
  def can_square_be_selected?(%Square{selected: false, letter: nil}), do: true
  def can_square_be_selected?(%Square{selected: false, letter: _letter}), do: false
  def can_square_be_selected?(%Square{selected: true}), do: false

  @doc """
  Updates the status log with a new status.

  Returns a game.
  """
  def update_status_log(%Game{status_log: status_log} = game, new_status) do
    {:ok, game} = update_game(game, %{status_log: status_log ++ [new_status]})
    game
  end

  def update_game(%Game{} = game, attrs \\ %{}) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
    |> broadcast(:game_updated, game.slug)
  end

  def delete_game(%Game{} = game) do
    Repo.delete(game)
    |> broadcast(:game_restarted, game.slug)
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

  def get_game_by_slug(slug) do
    Repo.get_by(Game, slug: slug)
    |> convert_json_to_game()
  end

  defp convert_json_to_game(nil), do: nil

  defp convert_json_to_game(game) do
    game
    |> Map.merge(%{board: game.board |> Enum.map(fn b -> Square.convert(b) end)})
    |> Map.merge(%{players: game.players |> Enum.map(fn p -> Player.convert(p) end)})
  end

  @doc """
  Creates or updates game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(%Room{slug: slug}, players) do
    case get_game_by_slug(slug) do
      nil ->
        %Game{
          slug: slug,
          status: "selecting",
          players: players,
          player_turn: 0,
          status_log: [],
          winning_squares: [],
          board: create_board()
        }
        |> Repo.insert()
        |> broadcast(:game_started, slug)

      game ->
        {:ok, game}
    end
  end

  defp create_board(_x \\ 3) do
    [
      # Row 1
      Square.build("sq11"),
      Square.build("sq12"),
      Square.build("sq13"),
      # Row 2
      Square.build("sq21"),
      Square.build("sq22"),
      Square.build("sq23"),
      # Row 3
      Square.build("sq31"),
      Square.build("sq32"),
      Square.build("sq33")
    ]
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

      :tie ->
        game
        |> set_status("done")
        |> update_status_log("TIE GAME!")

      [sq1, sq2, sq3] ->
        game
        |> Map.merge(%{winning_squares: [sq1, sq2, sq3]})
        |> set_status("done")
        |> update_status_log("#{player.name} won the game!")
    end
  end

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
        if all_squares_taken?(board), do: :tie, else: :not_found
    end
  end

  @doc """
  Creates a unique code.
  """
  def generate_room_code() do
    # Generate a single 4 character random code
    range = ?A..?Z

    1..2
    |> Enum.map(fn _ -> [Enum.random(range)] |> List.to_string() end)
    |> Enum.join("")
  end

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms do
    Repo.all(Room)
  end

  @doc """
  Gets a single room via slug.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room_slug!("123")
      %Room{}

      iex> get_room_slug!("456")
      ** (Ecto.NoResultsError)
  """
  def get_room_slug!(slug), do: Repo.get_by!(Room, slug: slug)

  def create_or_get_room_slug(slug) do
    case Repo.get_by(Room, slug: slug) do
      nil ->
        {:ok, room} = create_room(slug)
        room

      room ->
        room
    end
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(slug) do
    slug = String.downcase(slug)

    %Room{}
    |> Room.changeset(%{slug: slug})
    |> Repo.insert()
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end
end
