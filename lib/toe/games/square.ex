defmodule Toe.Games.Square do
  # this just means we can reference Square as a module (https://dockyard.com/blog/2017/08/15/elixir-tips)
  alias __MODULE__

  @derive Jason.Encoder
  defstruct [:name, :letter, :color, selected: false]

  @doc """
  Build and returns a board square.
  Requires a name, ie
  """
  def build(name, letter \\ nil, color \\ nil) do
    %Square{name: name, letter: letter, color: nil, selected: false}
  end

  @doc """
  Converts from JSON to Square.
  """
  def convert(%{"letter" => letter, "name" => name, "selected" => selected, "color" => color}) do
    %Square{name: name, letter: letter, selected: selected, color: color}
  end

  @doc """
  Return if the square is open. True if no player has claimed the square. False
  if a player occupies it.
  ## Example
      iex> is_open?(%Square{name: :sq11, letter: nil})
      true
      iex> is_open?(%Square{name: :sq11, letter: "O"})
      false
      iex> is_open?(%Square{name: :sq11, letter: "X"})
      false
  """
  def is_open?(%Square{letter: nil}), do: true
  def is_open?(%Square{}), do: false
end
