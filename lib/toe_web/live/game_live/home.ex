defmodule ToeWeb.GameLive.Home do
  @moduledoc """
  Home page.
  """
  use ToeWeb, :live_view
  alias Toe.Games

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("create-or-join-room", %{"room" => room}, socket) do
    room =
      room
      |> String.replace(~r/[^\w-]+/u, "")
      |> String.downcase()

    {:noreply, push_redirect(socket, to: Routes.game_index_path(socket, :play, room))}
  end

  def handle_event("start", _, socket) do
    slug = Games.generate_room_code()
    {:ok, room} = Games.create_room(slug)
    {:noreply, push_redirect(socket, to: Routes.game_index_path(socket, :play, room.slug))}
  end
end
