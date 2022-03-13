defmodule Toe.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :slug, :string

      timestamps()
    end

    create index(:rooms, [:slug], unique: true)
  end
end
