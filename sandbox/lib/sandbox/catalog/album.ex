defmodule Sandbox.Catalog.Album do
  @moduledoc """
  The `albums` table as an Ash resource, forbid-by-default so the actor path is actually exercised.

  The read policy only passes for an actor marked `admin?`. Without one, `Ash.read!/2` refuses the action, so
  `Pax.Adapters.Ash` must resolve the actor per call or the page cannot load at all. The `rating` filter is the
  quieter case: an actor that is not an admin reviewer sees no unrated albums and no error either.
  """
  use Ash.Resource,
    domain: Sandbox.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("albums")
    repo(Sandbox.Repo)
    migrate?(false)
  end

  attributes do
    integer_primary_key(:id)
    attribute(:uuid, :uuid, public?: true)
    attribute(:name, :string, public?: true, allow_nil?: false)
    attribute(:rating, :float, public?: true)
    attribute(:length_sec, :integer, public?: true, allow_nil?: false)
    attribute(:artist_id, :integer, public?: true, allow_nil?: false)
    attribute(:label_id, :integer, public?: true)
    create_timestamp(:inserted_at, public?: true)
    update_timestamp(:updated_at, public?: true)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
    default_accept(:*)
  end

  policies do
    policy action_type(:read) do
      authorize_if(expr(^actor(:admin?) == true))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(expr(^actor(:admin?) == true))
    end
  end
end
