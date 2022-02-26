defmodule Toe.Repo.Migrations.CreateGame do
  use Ecto.Migration

  def change do
    create table(:game) do
      add :slug, :string
      add :status, :string
      add :players, {:array, :map}
      add :player_turn, :integer
      add :status_log, {:array, :string}
      add :winning_squares, {:array, :map}
      add :board, {:array, :map}

      timestamps()
    end
  end
end
