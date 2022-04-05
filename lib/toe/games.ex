defmodule Toe.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Toe.Repo
  alias Toe.Games.{Game, Square, Player, Room}
  alias Toe.Games.Log

  def flags(), do: ["X", "O", "&", "!", "#"]
  def colors(), do: ["blue", "teal", "orange", "stone", "red"]

  @doc """
  Takes a list of player names and converts them to a list of %Player{}'s

  create_player_list(["bob", "charlie"])
  > [%Player{name: "bob", letter: "X"}, %Player{name: "charlie", letter: "X"}]

  """
  def create_player_list(player_names) when is_list(player_names) do
    flags = flags()

    player_names
    |> Enum.with_index()
    |> Enum.map(fn {name, i} ->
      %Player{
        name: name,
        letter: Enum.at(flags, rem(i, length(player_names))),
        color: Enum.at(colors, i)
      }
    end)
  end

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
    |> broadcast(:game_updated, game.slug)
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
  def submit_bid(
        %Game{players: players} = game,
        %Player{points: points, name: name} = player,
        bid
      )
      when points >= bid and is_number(bid) do
    [%Square{name: square_name}] = game.board |> Enum.filter(fn sq -> sq.selected end)

    game =
      update_player_bid(game, player, bid)
      |> update_status_log("#{name} bid #{bid} on square #{square_name}")

    cond do
      all_players_bid?(game) and any_ties?(game) ->
        game =
          game
          |> set_all_bids_to_nil()
          |> update_status_log("Bids are tied, bid again")

        broadcast({:ok, game}, :game_updated, game.slug)

      all_players_bid?(game) ->
        resolve_bids(game, player, bid)

      true ->
        {:ok, game} |> broadcast(:game_updated, game.slug)
    end
  end

  defp resolve_bids(
         %Game{players: players} = game,
         %Player{points: points, name: name} = player,
         bid
       ) do
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

    Returns {:ok, game}
    """

    max_bid = Enum.max(Enum.map(players, fn p -> p.bid end))
    bid_winner = Enum.find(players, fn p -> p.bid == max_bid end)
    selected_square = get_selected_square(game)

    game
    |> subtract_bids()
    |> set_all_bids_to_nil()
    |> set_selections_to_nil()
    |> set_status("selecting")
    |> set_square_letter(selected_square, bid_winner)
    |> update_status_log("#{bid_winner.name} wins the bid with #{max_bid}")
    |> check_for_win(bid_winner)
    |> next_turn()
    |> broadcast(:game_updated, game.slug)
  end

  defp any_ties?(%Game{players: players}) do
    [bid1, bid2] = Enum.map(players, fn p -> p.bid end) |> Enum.sort(:desc) |> Enum.slice(0..1)
    bid1 == bid2
  end

  defp update_player_bid(%Game{players: players} = game, %Player{name: name}, bid) do
    players =
      Enum.map(players, fn p ->
        if p.name == name,
          do: %{p | bid: bid},
          else: p
      end)

    {:ok, game} = update_game(game, %{players: players})
    game
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

  defp set_square_letter(%Game{board: board} = game, %Square{name: name}, %Player{
         letter: letter,
         color: color
       }) do
    board =
      Enum.map(board, fn sq ->
        if sq.name == name,
          do: %{sq | letter: letter, color: color},
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
  Get the player's name whose turn it is.
  """
  def current_player_turn(%Game{player_turn: player_turn, players: players}) do
    Enum.at(players, player_turn).name
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
  Updates the status log with a new status. Also saves log to logs db.

  Returns a game.
  """
  def update_status_log(%Game{status_log: status_log} = game, new_status) do
    {:ok, game} = update_game(game, %{status_log: [new_status] ++ status_log})
    {:ok, _status} = create_log(game, %{status: new_status})
    game
  end

  @doc """
  Updates a game
  """
  def update_game(%Game{} = game, attrs \\ %{}) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
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
        winning_squares_str = [sq1, sq2, sq3] |> Enum.map(&Atom.to_string(&1))

        room = get_room_slug!(game.slug)
        new_scores = Map.update(room.scores, player.name, 1, &(&1 + 1))
        {:ok, room} = update_room(room, %{scores: new_scores})

        {:ok, game} =
          game
          |> set_status("done")
          |> update_status_log("#{player.name} won the game!")
          |> update_game(%{winning_squares: winning_squares_str})
          |> broadcast(:game_updated, game.slug)

        game
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

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %Log{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_log(%Game{slug: slug}, attrs \\ %{}) do
    %Log{slug: slug}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end
end
