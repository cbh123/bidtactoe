defmodule Toe.Repo.Migrations.CreateGame do
  use Ecto.Migration

  def change do
    create table(:game) do
      add :slug, :string
      add :player1, {:map, :string}
      add :player2, {:map, :string}
      add :player1_points, :integer
      add :player2_points, :integer
      add :player_turn, :integer
      add :status, :string
      add :board, {:array, :string}

      timestamps()
    end
  end
end
