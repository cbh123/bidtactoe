defmodule Toe.Repo.Migrations.ChangeLogsToText do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      modify :status, :text
    end
  end
end
