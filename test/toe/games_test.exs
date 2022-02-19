defmodule Toe.GamesTest do
  use Toe.DataCase

  alias Toe.Games

  describe "game" do
    alias Toe.Games.Game

    import Toe.GamesFixtures

    @invalid_attrs %{board: nil, p: nil, player1_points: nil, player2: nil, player2_points: nil, player_turn: nil, players1: nil, slug: nil, status: nil}

    test "list_game/0 returns all game" do
      game = game_fixture()
      assert Games.list_game() == [game]
    end

    test "get_game!/1 returns the game with given id" do
      game = game_fixture()
      assert Games.get_game!(game.id) == game
    end

    test "create_game/1 with valid data creates a game" do
      valid_attrs = %{board: [], p: "some p", player1_points: "some player1_points", player2: "some player2", player2_points: "some player2_points", player_turn: "some player_turn", players1: "some players1", slug: "some slug", status: "some status"}

      assert {:ok, %Game{} = game} = Games.create_game(valid_attrs)
      assert game.board == []
      assert game.p == "some p"
      assert game.player1_points == "some player1_points"
      assert game.player2 == "some player2"
      assert game.player2_points == "some player2_points"
      assert game.player_turn == "some player_turn"
      assert game.players1 == "some players1"
      assert game.slug == "some slug"
      assert game.status == "some status"
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_game(@invalid_attrs)
    end

    test "update_game/2 with valid data updates the game" do
      game = game_fixture()
      update_attrs = %{board: [], p: "some updated p", player1_points: "some updated player1_points", player2: "some updated player2", player2_points: "some updated player2_points", player_turn: "some updated player_turn", players1: "some updated players1", slug: "some updated slug", status: "some updated status"}

      assert {:ok, %Game{} = game} = Games.update_game(game, update_attrs)
      assert game.board == []
      assert game.p == "some updated p"
      assert game.player1_points == "some updated player1_points"
      assert game.player2 == "some updated player2"
      assert game.player2_points == "some updated player2_points"
      assert game.player_turn == "some updated player_turn"
      assert game.players1 == "some updated players1"
      assert game.slug == "some updated slug"
      assert game.status == "some updated status"
    end

    test "update_game/2 with invalid data returns error changeset" do
      game = game_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_game(game, @invalid_attrs)
      assert game == Games.get_game!(game.id)
    end

    test "delete_game/1 deletes the game" do
      game = game_fixture()
      assert {:ok, %Game{}} = Games.delete_game(game)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(game.id) end
    end

    test "change_game/1 returns a game changeset" do
      game = game_fixture()
      assert %Ecto.Changeset{} = Games.change_game(game)
    end
  end
end
