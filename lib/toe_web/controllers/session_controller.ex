defmodule ToeWeb.SessionController do
  use ToeWeb, :controller

  def set(conn, %{"username" => username}) do
    IO.puts("saving session for #{username}")

    conn
    |> put_session(:username, username)
    |> json("OK!")
  end
end
