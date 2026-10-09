defmodule PaxTest.Catalog.Blob do
  @moduledoc "A custom Ash type, so the adapter's unknown-type error is reachable."
  use Ash.Type

  @impl true
  def storage_type(_), do: :binary

  @impl true
  def cast_input(value, _), do: {:ok, value}

  @impl true
  def cast_stored(value, _), do: {:ok, value}

  @impl true
  def dump_to_native(value, _), do: {:ok, value}
end

defmodule PaxTest.Catalog do
  @moduledoc """
  An Ash domain for testing `Pax.Adapters.Ash`, backed by ETS so the library tests need no database.

  Each resource sets `private? true`, which scopes its ETS table to the calling process, so these resources can
  be used by async tests without seeing each other's rows.
  """
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(PaxTest.Catalog.Album)
    resource(PaxTest.Catalog.Ticket)
    resource(PaxTest.Catalog.Oddity)
  end
end

defmodule PaxTest.Catalog.Album do
  @moduledoc "Every Ash type the adapter supports, plus a policy-free read."
  use Ash.Resource, domain: PaxTest.Catalog, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    attribute(:id, :integer,
      primary_key?: true,
      allow_nil?: false,
      writable?: true,
      public?: true,
      default: &PaxTest.Catalog.Album.next_id/0
    )

    attribute(:name, :string, public?: true, allow_nil?: false)
    attribute(:subtitle, :ci_string, public?: true)
    attribute(:uuid, :uuid, public?: true)
    attribute(:uuid7, :uuid_v7, public?: true)
    attribute(:rank, :integer, public?: true)
    attribute(:rating, :float, public?: true)
    attribute(:active, :boolean, public?: true)
    attribute(:released_on, :date, public?: true)
    attribute(:doors_at, :time, public?: true)
    attribute(:created_at, :utc_datetime, public?: true)
    attribute(:updated_at, :utc_datetime_usec, public?: true)
    attribute(:noted_at, :naive_datetime, public?: true)
    attribute(:kind, :atom, public?: true)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
    default_accept(:*)
  end

  false
  def next_id, do: System.unique_integer([:positive, :monotonic])
end

defmodule PaxTest.Catalog.Ticket do
  @moduledoc "A composite primary key, a non-primary read action, and a forbid-by-default policy."
  use Ash.Resource,
    domain: PaxTest.Catalog,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  ets do
    private?(true)
  end

  attributes do
    attribute(:event_id, :integer, primary_key?: true, allow_nil?: false, public?: true, writable?: true)
    attribute(:seat, :string, primary_key?: true, allow_nil?: false, public?: true, writable?: true)
    attribute(:holder, :string, public?: true)
  end

  actions do
    defaults([:destroy, create: :*, update: :*])
    default_accept(:*)

    read :read do
      primary?(true)
    end

    read(:admin_read)
  end

  # A filter policy, so a read with no actor quietly matches no rows rather than raising. That is the failure
  # mode an adapter that cannot see the actor produces: an empty page and no error anywhere.
  policies do
    policy action_type(:read) do
      authorize_if(expr(holder == ^actor(:name)))
    end

    policy always() do
      authorize_if(always())
    end
  end
end

defmodule PaxTest.Catalog.Oddity do
  @moduledoc "Types the adapter does not support yet, so the error paths are covered."
  use Ash.Resource, domain: PaxTest.Catalog, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    integer_primary_key(:id, writable?: true, generated?: false)
    attribute(:price, :decimal, public?: true)
    attribute(:meta, :map, public?: true)
    attribute(:extra, :keyword, public?: true, constraints: [fields: [note: [type: :string]]])
    attribute(:status, :atom, public?: true, constraints: [one_of: [:draft, :live]])
    attribute(:tags, {:array, :string}, public?: true)
    attribute(:blob, PaxTest.Catalog.Blob, public?: true)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
    default_accept(:*)
  end
end
