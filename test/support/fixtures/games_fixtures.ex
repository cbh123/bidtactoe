defmodule Toe.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Toe.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        board: [],
        p: "some p",
        player1_points: "some player1_points",
        player2: "some player2",
        player2_points: "some player2_points",
        player_turn: "some player_turn",
        players1: "some players1",
        slug: "some slug",
        status: "some status"
      })
      |> Toe.Games.create_game()

    game
  end
end
