defmodule Toe.Repo.Migrations.ChangeWinningSquaresToArrayString do
  use Ecto.Migration

  def change do
    alter table(:game) do
      modify :winning_squares, {:array, :string}
    end
  end
end
