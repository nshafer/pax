defmodule Pax.Adapters.AshTest do
  use ExUnit.Case, async: true

  alias Pax.Adapters.Ash, as: Adapter
  alias PaxTest.Catalog.{Album, Oddity, Ticket}

  @opts Adapter.init(nil, resource: Album)

  # A socket shaped the way Pax leaves it, since every data callback reads the fields and config off it.
  defp socket(opts \\ []) do
    config =
      Pax.Config.validate!(
        %{adapter: Adapter.config_spec(@opts)},
        adapter: Keyword.take(opts, [:actor, :tenant])
      )

    pax = %Pax.Interface{config: config, fields: Keyword.get(opts, :fields, [])}
    %{assigns: %{pax: pax}}
  end

  defp album!(attrs), do: Ash.create!(Album, attrs, authorize?: false)

  describe "init/2" do
    test "keeps the resource, domain and actions" do
      opts = Adapter.init(nil, resource: Album, domain: PaxTest.Catalog, read_action: :read)

      assert opts.resource == Album
      assert opts.domain == PaxTest.Catalog
      assert opts.read_action == :read
      assert opts.create_action == nil
      assert opts.update_action == nil
    end

    test "raises on an unknown option" do
      assert_raise ArgumentError, ~r/unknown options \[:nope\]/, fn ->
        Adapter.init(nil, resource: Album, nope: true)
      end
    end
  end

  describe "config_spec/1 and options" do
    test "the spec is valid" do
      spec = %{adapter: Adapter.config_spec(@opts)}
      assert {:ok, %{}} = Pax.Config.validate(spec, %{}, validate_config_spec: true)
    end

    test "the moduledoc documents the options" do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} = Code.fetch_docs(Adapter)
      assert doc =~ "## Options"
      assert doc =~ ":resource"
    end
  end

  describe "merge_config/3" do
    test "config overrides the init opts" do
      config =
        Pax.Config.validate!(%{resource: [:module], read_action: [:atom]}, resource: Ticket, read_action: :admin_read)

      opts = Adapter.merge_config(@opts, config, socket())

      assert opts.resource == Ticket
      assert opts.read_action == :admin_read
    end

    test "raises without a resource" do
      opts = Adapter.init(nil, [])

      assert_raise RuntimeError, ~r/You must provide a `resource` in the config/, fn ->
        Adapter.merge_config(opts, %{}, socket())
      end
    end
  end

  describe "default_fields/1" do
    test "primary keys are immutable and nullable attributes are optional" do
      fields = Adapter.default_fields(@opts)

      assert {:id, :integer, [immutable: true]} in fields
      assert {:name, :string, [required: true]} in fields
      assert {:rank, :integer, [required: false]} in fields
    end

    test "attributes of unsupported types are left out" do
      names = Adapter.default_fields(Adapter.init(nil, resource: Oddity)) |> Enum.map(&elem(&1, 0))

      assert names == [:id]
    end
  end

  describe "field_type/2" do
    test "maps every supported Ash type" do
      for {field, type} <- [
            name: :string,
            subtitle: :string,
            uuid: :string,
            uuid7: :string,
            rank: :integer,
            rating: :float,
            active: :boolean,
            released_on: :date,
            doors_at: :time,
            created_at: :datetime,
            updated_at: :datetime,
            noted_at: :datetime,
            kind: :string,
            id: :integer
          ] do
        assert Adapter.field_type(@opts, field) == {:ok, type}, "expected #{field} to be #{type}"
      end
    end

    test "reports the types that need Pax field types that do not exist yet" do
      opts = Adapter.init(nil, resource: Oddity)

      assert Adapter.field_type(opts, :price) == {:error, "TODO: decimals"}
      assert Adapter.field_type(opts, :meta) == {:error, "TODO: maps"}
      assert Adapter.field_type(opts, :extra) == {:error, "TODO: maps"}
      assert Adapter.field_type(opts, :status) == {:error, "TODO: Enums"}
      assert Adapter.field_type(opts, :tags) == {:error, "TODO: arrays"}
    end

    test "reports an unknown custom type" do
      opts = Adapter.init(nil, resource: Oddity)

      assert {:error, message} = Adapter.field_type(opts, :blob)
      assert message =~ "Unknown Ash type PaxTest.Catalog.Blob"
      assert message =~ "must create a custom Type module"
    end

    test "reports an unknown field" do
      assert Adapter.field_type(@opts, :nope) ==
               {:error, "Unknown field :nope for resource PaxTest.Catalog.Album"}
    end
  end

  describe "names" do
    test "come from the resource module" do
      assert Adapter.singular_name(@opts) == "Album"
      assert Adapter.plural_name(@opts) == "Albums"
    end
  end

  describe "id_fields/1 and object_ids/2" do
    test "come from the primary key" do
      assert Adapter.id_fields(@opts) == [:id]
      assert Adapter.id_fields(Adapter.init(nil, resource: Ticket)) == [:event_id, :seat]
      assert Adapter.object_ids(@opts, %{id: 1}) == nil
    end
  end

  describe "object_name/2" do
    test "uses the first of name, title or label the resource has" do
      assert Adapter.object_name(@opts, %{id: 1, name: "Dune"}) == "Dune"
    end

    test "falls back to the name and primary key" do
      assert Adapter.object_name(@opts, %{id: 1, name: nil}) == "Album 1"
    end

    test "names every key of a composite primary key" do
      opts = Adapter.init(nil, resource: Ticket)

      assert Adapter.object_name(opts, %{event_id: 1, seat: "A1"}) == "Ticket event_id:1 seat:A1"
    end
  end

  describe "count_objects/3 and list_objects/3" do
    test "count and list the resource" do
      album!(%{name: "Dune"})
      album!(%{name: "Emma"})

      assert Adapter.count_objects(@opts, %{}, socket()) == 2
      assert Adapter.list_objects(@opts, %{}, socket()) |> length() == 2
    end

    test "apply the order_by, limit, offset and filter criteria" do
      album!(%{name: "Dune", rank: 2})
      album!(%{name: "Emma", rank: 1})

      names = fn criteria -> Adapter.list_objects(@opts, criteria, socket()) |> Enum.map(& &1.name) end

      assert names.(%{order_by: [asc: :rank]}) == ["Emma", "Dune"]
      assert names.(%{order_by: :name}) == ["Dune", "Emma"]
      assert names.(%{order_by: :name, limit: 1}) == ["Dune"]
      assert names.(%{order_by: :name, limit: 1, offset: 1}) == ["Emma"]
      assert names.(%{filter: [name: "Emma"]}) == ["Emma"]
      assert Adapter.count_objects(@opts, %{filter: [name: "Emma"]}, socket()) == 1
    end

    test "translate Pax's nulls ordering to Ash's nils" do
      album!(%{name: "Dune", rating: 5.0})
      album!(%{name: "Emma"})

      names = fn criteria -> Adapter.list_objects(@opts, criteria, socket()) |> Enum.map(& &1.name) end

      assert names.(%{order_by: [asc_nulls_last: :rating]}) == ["Dune", "Emma"]
      assert names.(%{order_by: [asc_nulls_first: :rating]}) == ["Emma", "Dune"]
      assert names.(%{order_by: [desc_nulls_last: :rating]}) == ["Dune", "Emma"]
      assert names.(%{order_by: [desc_nulls_first: :rating]}) == ["Emma", "Dune"]
    end

    test "use a configured read action" do
      opts = Adapter.init(nil, resource: Ticket, read_action: :admin_read)
      Ash.create!(Ticket, %{event_id: 1, seat: "A1", holder: "ursula"}, authorize?: false)

      assert Adapter.list_objects(opts, %{}, socket(actor: %{name: "ursula"})) |> length() == 1
    end
  end

  describe "new_object/2" do
    test "is a bare struct" do
      assert %Album{id: nil, name: nil} = Adapter.new_object(@opts, socket())
    end
  end

  describe "get_object/4" do
    test "looks the object up by the primary key" do
      album = album!(%{name: "Dune"})

      assert Adapter.get_object(@opts, %{id: album.id}, %{}, socket()).name == "Dune"
    end

    test "looks up a composite primary key" do
      opts = Adapter.init(nil, resource: Ticket)
      Ash.create!(Ticket, %{event_id: 1, seat: "A1", holder: "ursula"}, authorize?: false)

      object = Adapter.get_object(opts, %{event_id: 1, seat: "A1"}, %{}, socket(actor: %{name: "ursula"}))

      assert object.holder == "ursula"
    end

    test "raises when there is no such object" do
      assert_raise Ash.Error.Query.NotFound, fn ->
        Adapter.get_object(@opts, %{id: -1}, %{}, socket())
      end
    end
  end

  describe "the actor" do
    setup do
      Ash.create!(Ticket, %{event_id: 1, seat: "A1", holder: "ursula"}, authorize?: false)
      %{opts: Adapter.init(nil, resource: Ticket)}
    end

    test "is resolved per call from the config", %{opts: opts} do
      assert Adapter.list_objects(opts, %{}, socket(actor: %{name: "ursula"})) |> length() == 1
      assert Adapter.count_objects(opts, %{}, socket(actor: %{name: "ursula"})) == 1
    end

    test "reads nothing, and raises nothing, for an actor the policy does not match", %{opts: opts} do
      assert Adapter.list_objects(opts, %{}, socket(actor: %{name: "octavia"})) == []
      assert Adapter.count_objects(opts, %{}, socket(actor: %{name: "octavia"})) == 0
    end

    test "refuses the read outright when there is no actor at all", %{opts: opts} do
      assert_raise Ash.Error.Forbidden, fn -> Adapter.list_objects(opts, %{}, socket()) end
    end

    test "can be a function of the socket", %{opts: opts} do
      assert Adapter.list_objects(opts, %{}, socket(actor: fn _socket -> %{name: "ursula"} end)) |> length() == 1
    end
  end

  describe "change_object/3, validate_object/5" do
    @fields [Pax.Field.init(nil, {:name, :string}), Pax.Field.init(nil, {:rank, :integer, required: false})]

    test "builds a create form for a new object, named so that Pax's events match" do
      socket = socket(fields: @fields)
      form = Adapter.change_object(@opts, Adapter.new_object(@opts, socket), socket)

      assert %AshPhoenix.Form{type: :create, resource: Album} = form

      # AshPhoenix.Form ignores the :as given to to_form/2, so the adapter must name the form itself.
      assert Phoenix.Component.to_form(form, as: Pax.Adapter.form_name()).name == "detail"
    end

    test "builds an update form for an existing object" do
      socket = socket(fields: @fields)
      album = album!(%{name: "Dune"})

      assert %AshPhoenix.Form{type: :update, name: "detail"} = Adapter.change_object(@opts, album, socket)
    end

    test "uses configured create and update actions" do
      opts = Adapter.init(nil, resource: Album, create_action: :create, update_action: :update)
      socket = socket(fields: @fields)

      assert %AshPhoenix.Form{action: :create} = Adapter.change_object(opts, %Album{}, socket)
      assert %AshPhoenix.Form{action: :update} = Adapter.change_object(opts, album!(%{name: "Dune"}), socket)
    end

    test "applies the params, and errors clear once they are fixed" do
      socket = socket(fields: @fields)
      form = Adapter.change_object(@opts, %Album{}, socket)

      invalid = Adapter.validate_object(@opts, nil, form, %{"name" => ""}, socket)
      assert AshPhoenix.Form.errors(invalid) == [name: "is required"]

      valid = Adapter.validate_object(@opts, nil, invalid, %{"name" => "Dune"}, socket)
      assert AshPhoenix.Form.errors(valid) == []
    end
  end

  describe "create_object/5 and update_object/5" do
    @fields [Pax.Field.init(nil, {:name, :string})]

    test "submit the form" do
      socket = socket(fields: @fields)
      form = Adapter.change_object(@opts, %Album{}, socket)

      assert {:ok, %Album{name: "Dune"} = album} =
               Adapter.create_object(@opts, %Album{}, form, %{"name" => "Dune"}, socket)

      update = Adapter.change_object(@opts, album, socket)

      assert {:ok, %Album{name: "Dune II"}} =
               Adapter.update_object(@opts, album, update, %{"name" => "Dune II"}, socket)
    end

    test "answer with the form when the action refuses" do
      socket = socket(fields: @fields)
      form = Adapter.change_object(@opts, %Album{}, socket)

      assert {:error, %AshPhoenix.Form{} = form} =
               Adapter.create_object(@opts, %Album{}, form, %{"name" => ""}, socket)

      assert AshPhoenix.Form.errors(form) == [name: "is required"]
    end
  end

  describe "the domain" do
    test "can be given explicitly" do
      opts = Adapter.init(nil, resource: Album, domain: PaxTest.Catalog)
      album!(%{name: "Dune"})

      assert Adapter.list_objects(opts, %{}, socket()) |> length() == 1
      assert %AshPhoenix.Form{} = Adapter.change_object(opts, %Album{}, socket(fields: []))
    end
  end

  describe "the tenant" do
    test "is resolved per call from the config" do
      album!(%{name: "Dune"})

      # The ETS data layer ignores it, but it must reach Ash without error.
      assert Adapter.list_objects(@opts, %{}, socket(tenant: "acme")) |> length() == 1
    end
  end
end
