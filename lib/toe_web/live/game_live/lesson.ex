defmodule ToeWeb.GameLive.Lesson do
  @moduledoc """
  Home page.
  """
  use ToeWeb, :live_view
  alias Toe.Games
  alias Toe.Games.Game

  @impl true
  def mount(_params, session, socket) do
    lesson_slug = ("home_example" <> session["_csrf_token"]) |> String.downcase()

    if connected?(socket) do
      Games.subscribe(lesson_slug)
    end

    {:ok, game} = start_game(lesson_slug, "you")

    {:ok,
     socket
     |> assign(
       username: "you",
       game: game,
       room: %{scores: nil},
       bid_outcome: [],
       slug: lesson_slug
     )}
  end

  defp start_game(slug, username) do
    players =
      %{username => %{is_computer: false}, "BidTacTeacher" => %{is_computer: true}}
      |> Games.create_player_list_from_map()

    slug
    |> Games.create_or_get_room_slug()
    |> Games.create_game(players)
  end

  def handle_event("create-or-join-room", %{"room" => room}, socket) do
    room =
      room
      |> String.replace(~r/[^\w-]+/u, "")
      |> String.downcase()

    {:noreply, push_redirect(socket, to: Routes.game_index_path(socket, :play, room))}
  end

  def handle_event("restart", _, socket) do
    Games.delete_game(socket.assigns.game)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select", %{"name" => name}, socket) do
    square = Enum.find(socket.assigns.game.board, fn s -> s.name == name end)

    cond do
      socket.assigns.game.status == "done" ->
        {:noreply, socket |> put_flash(:info, "The game is over!")}

      socket.assigns.game.status != "selecting" ->
        {:noreply, socket |> put_flash(:error, "We're in bidding phase, select a square after!")}

      find_me(socket.assigns.game, socket.assigns.username) |> is_nil() ->
        {:noreply, socket |> put_flash(:info, "Spectators can't play! You fool.")}

      Games.current_player_turn(socket.assigns.game) != socket.assigns.username ->
        {:noreply, socket |> put_flash(:error, "It's not your turn to select!")}

      not Games.can_square_be_selected?(square) ->
        {:noreply, socket |> put_flash(:error, "That square already has been won!")}

      socket.assigns.game.status == "selecting" and Games.can_square_be_selected?(square) ->
        Games.declare_selected_square(socket.assigns.game, square)
        {:noreply, socket}
    end
  end

  def handle_event("submit-bid", %{"bid" => %{"bid" => bid}}, socket) do
    player = find_me(socket.assigns.game, socket.assigns.username)
    bid = String.to_integer(bid)

    case Games.submit_bid(socket.assigns.game, player, bid) do
      {:error, message} ->
        {:noreply, socket |> put_flash(:error, message)}

      {:ok, _game} ->
        {:noreply, socket |> assign(bid: 0) |> push_event("play-sound", %{})}
    end
  end

  @impl true
  def handle_info({:game_started, game}, socket) do
    {:noreply, assign(socket, game: game) |> clear_flash()}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    bid_outcome =
      if bid_completed?(game.status_log), do: parse_bids(game.status_log, game), else: []

    if game.status == "selecting" and Enum.at(game.players, game.player_turn).is_computer do
      open_squares = Enum.filter(game.board, fn sq -> is_nil(sq.letter) end)
      choice = open_squares |> Enum.random()
      Games.declare_selected_square(game, choice)
    end

    {:noreply,
     assign(socket, game: game, bid_outcome: bid_outcome)
     |> clear_flash()}
  end

  @impl true
  def handle_info({:game_restarted, _game}, socket) do
    game = Games.get_game_by_slug(socket.assigns.slug)

    {:noreply,
     socket
     |> assign(game: game)
     |> push_redirect(to: Routes.game_lesson_path(socket, :lesson))}
  end

  defp bid_completed?([last_status_log | _]) do
    String.contains?(last_status_log, "wins the bid")
  end

  defp bid_completed?(_), do: false

  defp parse_bids_helper(status, winner) do
    status = status |> String.split()
    name = status |> Enum.at(0)
    bid = status |> Enum.at(-4) |> String.to_integer()
    %{name: name, bid: bid, won: winner == name}
  end

  defp parse_bids([last | _] = status_log, game)
       when length(status_log) >= length(game.players) + 1 do
    winner = last |> String.split() |> Enum.at(0)

    Enum.map(1..length(game.players), fn i ->
      Enum.at(status_log, i) |> parse_bids_helper(winner)
    end)
  end

  defp parse_bids(_, _), do: []

  def find_me(%Game{players: players}, name) do
    Enum.find(players, fn p -> p.name == name end)
  end

  defp spinny_thing() do
    """
    <svg fill="currentColor" class="ml-2 w-6 h-6 inline-flex group-hover:animate-spin"
    viewBox="0 0 396.593 396.594">
    <g>
        <g>
            <path d="M232.114,45.272c-25.092-20.196-55.692-30.6-84.456-44.676c-4.896-1.836-11.016,0.612-11.016,6.732
    c0,7.956,0,15.912,1.836,23.256C-21.254,2.432-48.182,356.168,137.254,372.08c6.732,0.611,6.732-8.568,1.224-10.404
    c-39.78-14.076-70.38-31.211-92.412-68.543c-19.584-34.273-25.704-75.277-23.256-114.445
    c4.284-72.828,46.512-135.864,119.952-134.64c0.612,1.224,1.224,3.06,2.448,4.284c-6.732,3.672-12.852,8.568-18.972,13.464
    c-4.284,3.672-1.836,10.404,3.06,11.628c34.884,9.792,70.379-2.448,101.592-17.136C234.562,55.064,235.786,48.332,232.114,45.272z
    M145.822,63.02c5.508-4.284,11.017-7.956,17.136-11.628c4.284-2.448,2.448-7.956-1.224-8.568c0.612-2.448,0-5.508-3.06-6.732
    c-1.836-0.612-3.061-1.224-4.896-1.224c-1.224-4.896-1.836-10.404-1.836-15.912c20.808,9.18,42.84,17.136,61.812,30.6
    C192.333,58.736,169.078,65.468,145.822,63.02z" />
            <path d="M371.65,96.68c-14.688-32.436-53.244-66.096-91.188-62.424c-6.731,0.612-8.567,9.792-1.836,12.24
    c36.108,12.24,61.812,20.808,80.172,57.528c17.137,34.272,17.748,76.5,11.628,113.832
    c-9.18,60.588-49.571,145.045-120.563,135.865c7.956-11.629,14.076-24.48,17.136-38.557c1.836-6.119-4.896-10.404-10.404-7.955
    c-31.823,14.076-61.199,31.822-88.128,53.855c-4.283,3.672-1.835,10.404,3.061,12.24c29.987,9.791,59.976,19.584,91.8,23.256
    c6.12,0.611,8.568-7.344,4.896-11.629c-4.896-4.895-9.793-12.852-15.301-19.584c75.889,11.016,119.952-79.559,131.58-144.432
    C391.845,179.912,389.398,135.236,371.65,96.68z M233.337,353.107C233.337,353.107,233.337,353.721,233.337,353.107
    c-1.224,1.225-1.836,2.449-2.447,3.061c-3.673,4.896,0.611,9.793,5.508,9.793c2.447,4.283,5.508,9.18,9.18,13.463
    c-18.972-4.283-37.944-9.791-56.916-15.912c18.36-14.688,38.556-26.316,59.977-36.719
    C244.354,335.973,239.458,344.541,233.337,353.107z" />
        </g>
    </g>
    </svg>
    """
  end
end
