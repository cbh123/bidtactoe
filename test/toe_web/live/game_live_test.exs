defmodule ToeWeb.GameLiveTest do
  use ToeWeb.ConnCase

  import Phoenix.LiveViewTest
  import Toe.GamesFixtures

  @create_attrs %{
    board: [],
    p: "some p",
    player1_points: "some player1_points",
    player2: "some player2",
    player2_points: "some player2_points",
    player_turn: "some player_turn",
    players1: "some players1",
    slug: "some slug",
    status: "some status"
  }
  @update_attrs %{
    board: [],
    p: "some updated p",
    player1_points: "some updated player1_points",
    player2: "some updated player2",
    player2_points: "some updated player2_points",
    player_turn: "some updated player_turn",
    players1: "some updated players1",
    slug: "some updated slug",
    status: "some updated status"
  }
  @invalid_attrs %{
    board: [],
    p: nil,
    player1_points: nil,
    player2: nil,
    player2_points: nil,
    player_turn: nil,
    players1: nil,
    slug: nil,
    status: nil
  }

  defp create_game(_) do
    game = game_fixture()
    %{game: game}
  end

  describe "Index" do
    setup [:create_game]

    test "lists all game", %{conn: conn, game: game} do
      {:ok, _index_live, html} = live(conn, Routes.game_index_path(conn, :index))

      assert html =~ "Listing Game"
      assert html =~ game.p
    end

    test "saves new game", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.game_index_path(conn, :index))

      assert index_live |> element("a", "New Game") |> render_click() =~
               "New Game"

      assert_patch(index_live, Routes.game_index_path(conn, :new))

      assert index_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#game-form", game: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.game_index_path(conn, :index))

      assert html =~ "Game created successfully"
      assert html =~ "some p"
    end

    test "updates game in listing", %{conn: conn, game: game} do
      {:ok, index_live, _html} = live(conn, Routes.game_index_path(conn, :index))

      assert index_live |> element("#game-#{game.id} a", "Edit") |> render_click() =~
               "Edit Game"

      assert_patch(index_live, Routes.game_index_path(conn, :edit, game))

      assert index_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#game-form", game: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.game_index_path(conn, :index))

      assert html =~ "Game updated successfully"
      assert html =~ "some updated p"
    end

    test "deletes game in listing", %{conn: conn, game: game} do
      {:ok, index_live, _html} = live(conn, Routes.game_index_path(conn, :index))

      assert index_live |> element("#game-#{game.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#game-#{game.id}")
    end
  end

  describe "Show" do
    setup [:create_game]

    test "displays game", %{conn: conn, game: game} do
      {:ok, _show_live, html} = live(conn, Routes.game_show_path(conn, :show, game))

      assert html =~ "Show Game"
      assert html =~ game.p
    end

    test "updates game within modal", %{conn: conn, game: game} do
      {:ok, show_live, _html} = live(conn, Routes.game_show_path(conn, :show, game))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Game"

      assert_patch(show_live, Routes.game_show_path(conn, :edit, game))

      assert show_live
             |> form("#game-form", game: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#game-form", game: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.game_show_path(conn, :show, game))

      assert html =~ "Game updated successfully"
      assert html =~ "some updated p"
    end
  end
end
