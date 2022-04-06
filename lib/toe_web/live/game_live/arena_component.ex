defmodule ToeWeb.GameLive.ArenaComponent do
  use ToeWeb, :live_component
  alias Toe.Games
  alias Toe.Games.Game
  alias Toe.Games.Player

  def handle_event("restart", _, socket) do
    Games.delete_game(socket.assigns.game)
    {:noreply, socket}
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

  defp tooltip_message(game, username) do
    cond do
      game.status == "selecting" and length(game.status_log) == 0 ->
        "The game has begun! Select a square. "

      game.status == "selecting" and length(game.status_log) >= 3 ->
        [last_status | _] = game.status_log

        "#{String.capitalize(last_status)}! Now it's #{Games.current_player_turn(game)}'s turn to select a square."

      game.status == "selecting" and Games.current_player_turn(game) == username ->
        "Now it's your turn to select a square."

      game.status == "selecting" ->
        "Now it's #{Games.current_player_turn(game)}'s turn to select a square."

      game.status == "bidding" ->
        [last | _] = game.status_log
        name = last |> String.split() |> Enum.at(0)

        "#{name |> String.capitalize()} selected a square. Now time to bid! The winner gets the square. #{waiting_on_message(game)}"
    end
  end

  defp last_bid_was_tie?(["Bids are tied, bid again" | _]), do: true
  defp last_bid_was_tie?(_), do: false

  defp show_points(bid_outcome, username) do
    [player] = Enum.filter(bid_outcome, fn b -> b.name == username end)
    %{bid: player.bid, won: player.won}
  end

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
