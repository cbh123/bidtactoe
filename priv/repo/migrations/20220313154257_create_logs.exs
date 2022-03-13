defmodule Toe.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :status, :string
      add :slug, :string

      timestamps()
    end

    create index(:logs, [:slug])
  end
end
