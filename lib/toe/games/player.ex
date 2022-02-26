defmodule Toe.Games.Player do
  alias __MODULE__

  @moduledoc """
  Player struct.
  """
  @derive Jason.Encoder
  defstruct [:name, :letter, :bid, points: 81]

  @doc """
  Converts from JSON to Square.
  """
  def convert(%{"name" => name, "letter" => letter, "bid" => bid, "points" => points}) do
    %Player{name: name, letter: letter, bid: bid, points: points}
  end
end
