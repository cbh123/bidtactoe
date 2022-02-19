defmodule ToeWeb.PageController do
  use ToeWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
