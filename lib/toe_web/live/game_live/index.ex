defmodule ToeWeb.GameLive.Index do
  use ToeWeb, :live_view
  alias ToeWeb.Presence
  alias Phoenix.Socket.Broadcast
  alias Toe.Games
  alias Toe.Games.Game
  alias Toe.Games.Player

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
     |> assign(game: Games.get_game_by_slug(slug))}
  end

  defp start_game(slug, connected_users) do
    players =
      connected_users
      |> filter_connected_users()
      |> create_player_list()

    slug
    |> Games.create_or_get_room_slug()
    |> Games.create_game(players)
  end

  defp create_player_list(player_names) when is_list(player_names) do
    flags = ["X", "O"]

    player_names
    |> Enum.with_index()
    |> Enum.map(fn {name, i} ->
      %Player{name: name, letter: Enum.at(flags, rem(i, 2))}
    end)
  end

  def handle_event("start", _, socket) do
    {:ok, game} = start_game(socket.assigns.slug, socket.assigns.connected_users)
    {:noreply, socket |> assign(game: game)}
  end

  def handle_event("save", %{"username" => username}, socket) do
    Presence.track(self(), "room:" <> socket.assigns.slug, username, %{})

    {:noreply,
     socket
     |> push_event("set-username", %{username: username})
     |> assign(username: username)}
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

      Games.current_player_turn(socket.assigns.game).name != socket.assigns.username ->
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

      _game ->
        {:noreply, socket |> assign(bid: 0)}
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
    {:noreply, assign(socket, game: game) |> clear_flash()}
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
end
