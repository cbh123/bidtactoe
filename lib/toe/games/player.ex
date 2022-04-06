defmodule Toe.Games.Player do
  alias __MODULE__

  @moduledoc """
  Player struct.
  """
  @derive Jason.Encoder
  defstruct [
    :name,
    :letter,
    :bid,
    :color,
    points: 81,
    is_computer: false,
    computer_strategy: "random"
  ]

  @doc """
  Converts from JSON to Square.
  """
  def convert(%{
        "name" => name,
        "letter" => letter,
        "bid" => bid,
        "points" => points,
        "color" => color,
        "is_computer" => is_computer,
        "computer_strategy" => computer_strategy
      }) do
    %Player{
      name: name,
      letter: letter,
      bid: bid,
      points: points,
      color: color,
      is_computer: is_computer,
      computer_strategy: computer_strategy
    }
  end
end
