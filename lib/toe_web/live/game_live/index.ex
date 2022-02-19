defmodule ToeWeb.GameLive.Index do
  use ToeWeb, :live_view

  alias Toe.Games
  alias Toe.Games.Game

  @impl true
  def mount(_params, _session, socket) do
    game = %Game{}
    {:ok, assign(socket, game: game)}
  end

  @impl true
  def handle_event("select", %{"name" => name}, socket) do
    game = Games.declare_selected_square(socket.assigns.game, String.to_atom(name))
    {:noreply, socket |> assign(game: game)}
  end
end
