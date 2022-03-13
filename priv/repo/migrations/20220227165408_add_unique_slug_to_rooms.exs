defmodule Toe.Repo.Migrations.AddUniqueSlugToRooms do
  use Ecto.Migration

  def change do
    create index(:game, [:slug], unique: true)
  end
end
