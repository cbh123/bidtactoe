defmodule ToeWeb.GameLive.Index do
  use ToeWeb, :live_view
  alias ToeWeb.Presence
  alias Phoenix.Socket.Broadcast
  alias Toe.Games
  alias Toe.Games.Game
  alias Toe.Games.Player

  @num_players 2
  @player_colors ["blue", "teal", "orange", "red", "green"]

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    slug = String.downcase(slug)

    if connected?(socket) do
      Games.subscribe(slug)
    end

    {:ok, _} = Presence.track(self(), "room:" <> slug, session["username"], %{})

    # if game already has started, we should load it

    {:ok,
     socket
     |> assign(username: session["username"])
     |> assign(connected_users: %{})
     |> assign(game: nil)
     |> assign(bid: 0)
     |> assign(slug: slug)
     |> assign(bid_outcome: [])
     |> assign(page_title: "Play Bid Tac Toe with me!")
     |> assign(game: Games.get_game_by_slug(slug))}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, socket |> assign(url: url)}
  end

  defp start_game(slug, connected_users) do
    players =
      connected_users
      |> filter_connected_users()
      |> Games.create_player_list()

    slug
    |> Games.create_or_get_room_slug()
    |> Games.create_game(players)
  end

  def handle_event("start", _, socket) do
    {:ok, game} = start_game(socket.assigns.slug, socket.assigns.connected_users)
    {:noreply, socket |> assign(game: game)}
  end

  def handle_event("save", %{"username" => username}, socket) do
    username =
      username
      |> String.replace(~r/[^\w-]+/u, "")
      |> String.downcase()

    Presence.track(self(), "room:" <> socket.assigns.slug, username, %{})

    {:noreply,
     socket
     |> push_event("set-username", %{username: username})}
  end

  @impl true
  def handle_event("updated_session_data", %{"username" => username}, socket) do
    {:noreply, assign(socket, username: username)}
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

  def handle_event("restart", _, socket) do
    Games.delete_game(socket.assigns.game)
    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "presence_diff"}, %{assigns: %{slug: slug}} = socket) do
    {:noreply,
     socket
     |> assign(:connected_users, Presence.list("room:" <> slug))}
  end

  @impl true
  def handle_info({:game_started, game}, socket) do
    {:noreply, assign(socket, game: game) |> clear_flash()}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    last_statuses = Enum.slice(game.status_log, 0, @num_players + 1)
    bid_outcome = if bid_completed?(last_statuses), do: parse_bids(last_statuses), else: []

    {:noreply,
     assign(socket, game: game, bid_outcome: bid_outcome)
     |> clear_flash()}
  end

  @impl true
  def handle_info({:game_restarted, _game}, socket) do
    game = Games.get_game_by_slug(socket.assigns.slug)
    {:noreply, socket |> assign(game: game) |> clear_flash()}
  end

  def find_me(%Game{players: players}, name) do
    Enum.find(players, fn p -> p.name == name end)
  end

  defp filter_connected_users(connected_users) do
    connected_users
    |> Map.keys()
    |> Enum.filter(fn username -> username != "" and not is_nil(username) end)
  end

  defp get_named_connected_users(connected_users) do
    connected_users |> Map.keys() |> Enum.filter(fn u -> u != "" end)
  end

  defp status_message(game, username, my_username) do
    blank = raw("&nbsp")
    up_arrow1 = up_arrow1()

    cond do
      game.status == "done" ->
        blank

      game.status == "bidding" and Games.has_bid_already?(game, username) ->
        "submitted"

      game.status == "bidding" ->
        "place a bid" <> up_arrow1

      username == my_username and Games.current_player_turn(game) == username ->
        "select a square" <> up_arrow1

      username != my_username and Games.current_player_turn(game) == username ->
        "waiting..."

      true ->
        raw("&nbsp")
    end
  end

  defp up_arrow1() do
    """
    <svg class="h-6 w-6 inline-block" viewBox="0 0 388.057 388.058">
    <g>
    <path d="M313.231,364.922c-14.688-38.556-28.764-77.112-45.288-115.056c-11.016-25.704-23.256-60.589-43.452-82.009
    c16.524-3.06,31.824-7.344,46.513-15.3c3.672-1.836,4.896-6.732,2.447-10.404c-16.523-29.988-32.436-60.588-50.796-89.352
    C212.25,36.277,190.831-2.891,166.351,0.169c-23.256,3.06-38.557,41.616-47.736,58.752c-15.912,31.824-27.54,65.484-43.452,96.696
    c-1.224,2.448-0.612,4.284,0.612,6.12c-1.836,2.448-1.225,6.732,1.836,8.568c12.24,6.732,25.092,7.956,38.556,7.344
    c6.12,0,15.912,0,23.868-2.448c-19.584,66.096-23.868,135.252-38.556,202.573c-1.225,6.731,5.508,12.852,11.628,9.18
    c25.704-15.912,64.26-62.424,96.084-53.856c33.048,9.181,62.424,29.376,93.636,41.616
    C308.947,377.162,315.067,370.43,313.231,364.922z M201.847,314.738c-27.54-2.448-56.305,26.315-80.784,45.899
    c12.24-63.647,17.748-128.52,30.6-191.556c0-1.224,0-2.448-0.612-3.672c0.612-1.836,0-3.672-1.836-4.896
    c-8.567-4.896-20.195,1.224-29.376,2.448c-11.628,1.224-22.644,0-33.659-3.06c11.628-20.196,19.584-42.84,29.376-63.648
    c12.239-25.704,25.092-63.036,48.96-80.784c19.584-14.688,74.664,93.636,91.8,126.684c-14.688,6.12-29.376,9.18-45.288,11.628
    c-3.672,0.612-4.896,3.06-5.508,5.508c-2.448,2.448-4.284,6.12-1.836,9.18c41.004,53.856,63.647,119.952,86.904,183.601
    C263.047,337.382,233.059,317.186,201.847,314.738z"/>
    </g>
    </svg>
    """
  end

  defp show_points(bid_outcome, username) do
    [player] = Enum.filter(bid_outcome, fn b -> b.name == username end)
    %{bid: player.bid, won: player.won}
  end

  defp bid_completed?([last_status_log, _status2, _status1]) do
    String.contains?(last_status_log, "wins the bid")
  end

  defp bid_completed?(_), do: false

  defp parse_bids([last, status2, status1]) do
    status1 = status1 |> String.split()
    status2 = status2 |> String.split()

    name1 = status1 |> Enum.at(0)
    bid1 = status1 |> Enum.at(-4)
    name2 = status2 |> Enum.at(0)
    bid2 = status2 |> Enum.at(-4)
    winner = last |> String.split() |> Enum.at(0)

    [
      %{name: name1, bid: bid1, won: winner == name1},
      %{name: name2, bid: bid2, won: winner == name2}
    ]
  end

  defp parse_bids(_), do: []

  defp last_bid_was_tie?(["Bids are tied, bid again" | _]), do: true
  defp last_bid_was_tie?(_), do: false

  defp last_move_was_bid_win?([hd | _]), do: String.contains?(hd, "wins the bid")
  defp last_move_was_bid_win?(_), do: false

  defp get_player_color(index) do
    "text-#{Enum.at(@player_colors, index)}-400"
  end
end
