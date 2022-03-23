defmodule ToeWeb.GameLive.Makeover do
  @moduledoc """
  Change username page.
  """
  use ToeWeb, :live_view

  def mount(_params, session, socket) do
    {:ok, socket |> assign(username: session["username"])}
  end

  def handle_event("save", %{"username" => username}, socket) do
    username =
      username
      |> String.replace(~r/[^\w-]+/u, "")
      |> String.downcase()

    {:noreply,
     socket
     |> push_event("set-username", %{username: username})
     |> assign(username: username)}
  end
end
