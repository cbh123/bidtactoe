defmodule Toe.Repo.Migrations.ChangeStatusToText do
  use Ecto.Migration

  def change do
    alter table(:game) do
      modify :status_log, {:array, :text}
    end
  end
end
