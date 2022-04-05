defmodule Toe.Repo.Migrations.AddRoomScores do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :scores, :map, default: %{}
    end
  end
end
