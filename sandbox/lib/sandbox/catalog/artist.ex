defmodule Sandbox.Catalog.Artist do
  @moduledoc "The `artists` table as an Ash resource, with a full set of actions."
  use Ash.Resource,
    domain: Sandbox.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("artists")
    repo(Sandbox.Repo)
    migrate?(false)
  end

  attributes do
    integer_primary_key(:id)
    attribute(:name, :string, public?: true, allow_nil?: false)
    attribute(:slug, :string, public?: true, allow_nil?: false)
    attribute(:rating, :float, public?: true)
    attribute(:started, :naive_datetime, public?: true, allow_nil?: false)
    attribute(:ended, :naive_datetime, public?: true)
    attribute(:current_label_id, :integer, public?: true)
    create_timestamp(:inserted_at, public?: true)
    update_timestamp(:updated_at, public?: true)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
    default_accept(:*)
  end
end
