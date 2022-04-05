defmodule ToeWeb.GameLive.Home do
  @moduledoc """
  Home page.
  """
  use ToeWeb, :live_view
  alias Toe.Games
  alias Toe.Games.Game
  alias Toe.Games.Player

  def mount(_params, session, socket) do
    players =
      ["You", "Joe Schmo"]
      |> Games.create_player_list()

    {:ok, game} =
      "home_example"
      |> Games.create_or_get_room_slug()
      |> Games.create_game(players)

    room = Games.get_room_slug!(game.slug)

    {:ok,
     socket
     |> assign(username: session["username"])
     |> assign(game: game, room: room, bid_outcome: [])}
  end

  def handle_event("start", _, socket) do
    slug = Games.generate_room_code()
    {:ok, room} = Games.create_room(slug)
    {:noreply, push_redirect(socket, to: Routes.game_index_path(socket, :play, room.slug))}
  end

  def find_me(%Game{players: players}, name) do
    Enum.find(players, fn p -> p.name == name end)
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

  defp last_bid_was_tie?(["Bids are tied, bid again" | _]), do: true
  defp last_bid_was_tie?(_), do: false

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

  defp get_player_color(%Player{color: color}), do: parse_color(color)
  defp parse_color(color), do: "text-#{color}-400"

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
end
