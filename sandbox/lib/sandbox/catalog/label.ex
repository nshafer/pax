defmodule Sandbox.Catalog.Label do
  @moduledoc "The `labels` table as an Ash resource. Read only, to show an interface with no write path."
  use Ash.Resource,
    domain: Sandbox.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("labels")
    repo(Sandbox.Repo)

    # Sandbox.Library's Ecto migrations own this table.
    migrate?(false)
  end

  attributes do
    integer_primary_key(:id)
    attribute(:name, :string, public?: true, allow_nil?: false)
    attribute(:slug, :string, public?: true, allow_nil?: false)
    attribute(:rating, :float, public?: true)
    attribute(:founded, :integer, public?: true, allow_nil?: false)
    attribute(:accepting_submissions, :boolean, public?: true, allow_nil?: false)
    create_timestamp(:inserted_at, public?: true)
    update_timestamp(:updated_at, public?: true)
  end

  actions do
    defaults([:read])
  end
end
