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
     |> assign(room: Games.get_room_slug!(slug))
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
    bid_outcome =
      if bid_completed?(game.status_log), do: parse_bids(game.status_log, game), else: []

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

  defp waiting_on_message(game) do
    waiting_on =
      game.players
      |> Enum.filter(&(&1.bid |> is_nil()))
      |> Enum.map(& &1.name)

    if length(waiting_on) != length(game.players) do
      "Waiting for #{waiting_on |> Enum.join(", ")}."
    else
      ""
    end
  end

  defp tooltip_message(game) do
    cond do
      game.status == "selecting" and length(game.status_log) >= 3 ->
        [last_status | _] = game.status_log

        "#{String.capitalize(last_status)}! Now it's #{Games.current_player_turn(game)}'s turn to select a square."

      game.status == "selecting" ->
        "Now it's #{Games.current_player_turn(game)}'s turn to select a square."

      true ->
        "Time to bid! The winner gets the square. #{waiting_on_message(game)}"
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

  defp curvy_up_arrow() do
    """
    <svg class="h-6 w-6 inline-block" viewBox="0 0 373.964 373.964">
      <g>
          <path d="M320.66,112.236c-11.627-22.032-25.092-44.064-38.555-64.872C275.373,36.96,265.58,18.601,253.339,9.42
          c0.613-1.224,0-2.448-0.611-3.672c-4.283-6.12-12.852-5.508-20.195-5.508c-10.404-0.612-20.809,0-31.213,1.224
          c-3.061,0.612-4.283,3.06-3.672,5.508c-22.644,29.988-44.676,61.812-60.588,96.084c-1.224,2.448-0.612,4.284,0.612,6.12
          c4.896,7.956,14.076,13.464,17.748,21.42c1.224,3.672,4.284,5.508,7.956,4.284c6.732-1.224,16.524-1.224,25.092-3.672
          c1.225,33.66,4.896,66.708,3.061,100.368c-1.225,18.36-6.121,51.408-22.645,66.708c-4.284-2.448-9.18-4.284-13.464-7.956
          c-6.732-5.508-7.344-14.688-7.956-22.644c0-3.672-2.448-6.12-6.12-6.12c-6.12,0-11.628-2.448-17.136-3.672
          c-3.06-0.612-6.12-1.836-9.18-2.448l0,0c0.612-3.672-1.836-7.344-6.12-7.344c-15.3,0.611-31.212,0.611-46.512,1.836
          c-2.448,0-3.672,1.836-4.284,3.06c-3.06-1.224-7.344,0.612-7.956,4.896C42.2,323.376,105.848,383.353,167.048,370.5
          c42.84,17.137,80.784-33.048,94.249-68.544c11.016-29.987,13.463-63.036,15.912-94.248c1.223-23.868,4.896-52.02,1.836-76.5
          c14.076,0,27.539-3.06,41.004-6.12C326.167,123.252,325.556,114.685,320.66,112.236z M187.857,116.521
          c-2.449,0.612-5.509,1.224-7.957,1.836c-5.508,0.612-11.016,1.224-16.524,3.06c-3.06-3.06-6.12-6.12-9.18-8.568
          c5.508-0.612,11.628-1.836,15.912-2.448c5.508-0.612,12.852-1.224,17.749-3.672C187.857,109.176,187.857,112.849,187.857,116.521z
          M135.836,273.193c1.224,13.464,7.956,26.316,19.584,33.048c-1.224,0.612-2.448,0.612-4.284,0.612
          c-19.584,2.448-31.824-22.645-36.72-41.004C120.536,270.133,129.104,271.969,135.836,273.193z M121.76,352.752
          c-40.392-12.239-59.364-55.079-61.2-94.248c0.612,0,0.612,0,1.224,0c14.076,1.837,28.764,1.837,42.84,1.837
          c3.672,39.168,39.168,83.231,75.888,44.063c19.583-21.42,23.869-55.08,25.093-82.62c2.447-39.78-1.225-81.396-4.285-121.176
          c-0.611-5.508-6.119-7.344-9.791-5.508c-6.733-5.508-17.749-1.836-25.705-0.612c-3.672,0.612-8.568,0.612-12.852,1.224
          c15.912-26.928,33.66-52.632,52.633-77.724c12.852,12.852,23.867,26.928,34.883,41.616c7.957,11.016,14.076,24.48,23.256,34.884
          c-7.344,0-14.688,0.612-22.031,1.224c-3.061-1.836-6.732-1.224-8.568,1.224c-3.061,1.224-3.672,5.508-1.225,7.956
          c3.672,64.872,12.854,134.64-8.566,197.064C208.664,343.573,163.376,365.605,121.76,352.752z M275.984,118.356
          c-2.447-3.672-9.18-3.672-10.404,1.224c-4.283,19.584-1.223,42.228-1.836,62.424c-0.611,29.376-3.059,58.141-8.568,86.904
          c-4.895,24.48-12.852,49.572-28.764,69.156c-9.18,11.016-18.971,15.3-29.988,18.36c1.225-0.612,1.836-1.225,3.061-2.448
          c69.768-54.468,50.184-168.301,44.676-246.637c6.121,0.612,12.852,0.612,18.973,0.612c5.508,0,18.359,2.448,18.359-6.732
          c0-3.672-2.447-5.508-6.119-6.12c0-0.612,0-1.224,0-1.836c-2.449-14.688-15.912-28.764-24.48-39.78
          c-11.016-14.688-22.645-29.988-35.496-42.84c3.672,0,7.344,0.612,10.404,0.612s7.344,1.224,11.016,2.448
          c3.061,4.896,7.344,9.18,11.016,14.076c8.568,10.404,16.525,21.42,23.869,33.048c12.24,17.748,23.867,36.108,37.943,52.632
          C299.853,115.296,288.224,117.744,275.984,118.356z" />
      </g>
    </svg>
    """
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

  defp show_points(bid_outcome, username) do
    [player] = Enum.filter(bid_outcome, fn b -> b.name == username end)
    %{bid: player.bid, won: player.won}
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

  defp last_bid_was_tie?(["Bids are tied, bid again" | _]), do: true
  defp last_bid_was_tie?(_), do: false

  defp get_player_color(%Player{color: color}), do: parse_color(color)
  defp parse_color(color), do: "text-#{color}-400"

  defp get_player_color_before_init(i), do: Games.colors() |> Enum.at(i) |> parse_color()

  defp curvy_arrow(assigns) do
    ~H"""
    <svg class="h-6 w-6 inline-block" viewBox="0 0 394.873 394.873">
        <g>
            <g>
                <path
                    d="M334.678,145.951c-19.584-38.556-59.364-58.752-99.756-67.32C134.553,57.211,43.365,121.471,0.525,208.375
    c-2.448,4.896,4.284,8.567,7.344,4.283C57.441,134.323,132.717,75.571,230.638,92.095
    c91.188,15.912,111.996,94.86,112.608,175.643c0,8.568,13.464,8.568,13.464,0C357.322,226.123,353.649,183.283,334.678,145.951z" />
                <path d="M220.846,114.739c-44.676-5.508-88.74,13.464-126.685,35.496c-22.032,12.852-67.32,41.616-64.872,72.215
    c0,2.448,3.06,3.061,4.896,1.225c39.78-56.304,107.1-98.532,178.705-96.696c79.561,2.448,89.353,76.5,89.353,140.148
    c0,9.18,14.075,9.18,14.075,0C316.317,196.135,303.466,125.143,220.846,114.739z" />
                <path d="M380.578,238.975c-6.12,13.464-25.704,69.156-47.124,66.096c-9.792-1.224-19.584-10.403-26.929-16.523
    c-12.852-9.792-25.703-20.196-39.168-29.376c-4.283-3.061-9.18,3.672-5.508,7.344c18.972,17.136,46.512,52.021,74.664,53.856
    c29.376,1.224,48.348-54.469,57.528-73.44C398.326,237.751,384.861,230.406,380.578,238.975z" />
            </g>
        </g>
    </svg>
    """
  end

  defp right_arrow(assigns) do
    ~H"""
    <svg fill="currentColor" class="h-6 w-6 group-hover:translate-x-1 inline-block"
    viewBox="0 0 330.781 330.781">
    <g>
        <g>
            <path
                d="M73.077,13.376C73.077,13.376,73.077,12.765,73.077,13.376C73.077,12.765,73.077,13.376,73.077,13.376z" />
            <path d="M292.785,130.269c0.612-2.448,0-4.284-1.224-5.508c1.224-3.06-0.612-7.344-3.672-9.18
    c-41.004-15.912-77.112-43.452-113.832-67.932c-25.704-17.136-53.244-31.212-81.396-44.676c-0.612,0-1.224-0.612-1.836-0.612
    c-2.448-3.672-8.568-3.06-9.792,1.836c-0.612,2.448-1.224,4.896-1.836,7.344l-0.612,0.612c-0.612-0.612-1.224-1.224-1.836-1.224
    c-1.224-0.612-2.448,0-3.06,0.612h-0.612c-0.612,0-0.612,0.612,0,0.612c1.836,0,0,1.224,0,0.612
    c-1.836,1.836-2.448,4.896-3.672,6.732c-3.672,7.344-9.18,13.464-13.464,20.196c-4.896,6.732-22.644,22.032-17.136,31.824
    c0,0.612,0.612,0.612,0.612,1.224c-2.448,41.004,0.612,82.008,1.836,123.012c1.224,40.392-0.612,83.844,6.732,124.235
    c0.612,3.061,2.448,4.284,4.896,4.284c11.016,24.48,90.577-27.54,100.369-33.66c28.151-17.748,55.691-36.72,82.008-56.916
    c11.628-9.18,44.063-27.54,46.512-43.452c0.612-2.447-0.612-4.283-1.836-5.508C284.829,166.989,290.336,148.628,292.785,130.269z
    M268.917,185.349c-10.403,5.508-21.42,18.972-29.376,25.704c-23.256,18.36-47.124,35.496-71.604,52.02
    c-34.271,23.257-69.768,44.064-109.548,55.08l0,0c3.672-39.779-1.836-82.62-3.672-122.399
    c-1.224-41.004-1.224-82.62-6.732-123.012c3.06-1.836,4.896-4.896,6.732-7.956c4.896-6.732,9.792-13.464,14.688-20.196
    c2.448-3.672,6.12-8.568,9.18-14.076c0.612,9.18,1.836,18.36,1.836,26.928c1.224,26.928,2.448,53.856,3.672,80.784
    c1.224,23.256,1.836,46.512,1.836,69.768c0,16.524-3.672,34.885-0.612,51.408c0.612,4.284,7.344,4.284,9.18,1.225
    c0.612-0.612,1.224-1.836,1.224-3.061l0,0c1.836,2.448,4.284,3.672,7.344,3.061c38.556-6.732,77.112-38.557,107.712-60.588
    c19.584-13.465,38.556-27.54,56.304-43.453c2.448-1.836,4.896-3.672,7.344-6.12C271.977,162.705,270.141,174.333,268.917,185.349z
    M186.909,198.2c-19.584,13.465-39.779,25.704-59.976,37.332c-7.344,4.284-19.584,7.956-27.54,13.465
    c9.792-29.988,1.836-74.664,0.612-102.205c-1.224-26.928-2.448-53.856-3.672-81.396c-0.612-13.464,0.612-29.988-0.612-44.676
    c28.153,15.912,55.692,30.6,82.62,48.348c22.645,15.3,45.288,31.212,68.545,44.676c8.567,4.896,18.972,11.628,29.376,14.076
    C250.557,155.361,218.121,176.78,186.909,198.2z" />
        </g>
    </g>
    </svg>
    """
  end

  def flags(), do: Games.flags()
end
