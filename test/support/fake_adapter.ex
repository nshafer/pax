defmodule PaxTest.FakeAdapter do
  @moduledoc """
  A Pax.Adapter whose answers are given as init opts, for testing how Pax uses adapters.

  Each callback returns the opt of the same name (or a default), and data callbacks report to the owning test.
  """
  @behaviour Pax.Adapter

  alias PaxTest.Owner

  def init(callback_module, opts), do: opts |> Map.new() |> Map.put(:callback_module, callback_module)

  def config_spec(_opts), do: %{fake_key: [:string, {:function, 1, :string}]}

  def merge_config(opts, config, socket) do
    Map.put(opts, :fake_key, Pax.Config.get(config, :fake_key, [socket], nil))
  end

  def default_fields(opts), do: Map.get(opts, :default_fields, [])

  def field_type(opts, name) do
    case Map.fetch(Map.get(opts, :field_types, %{}), name) do
      {:ok, type} -> {:ok, type}
      :error -> {:error, "fake adapter has no field #{inspect(name)}"}
    end
  end

  def singular_name(opts), do: Map.get(opts, :singular_name)
  def plural_name(opts), do: Map.get(opts, :plural_name)
  def id_fields(opts), do: Map.get(opts, :id_fields)
  def object_ids(_opts, _object), do: nil
  def object_name(opts, object), do: Map.get(opts, :object_name, fn _ -> nil end).(object)

  def count_objects(opts, criteria) do
    Owner.notify({__MODULE__, :count_objects, criteria})
    length(Map.get(opts, :objects, []))
  end

  def list_objects(opts, criteria) do
    Owner.notify({__MODULE__, :list_objects, criteria})
    Map.get(opts, :objects, [])
  end

  def new_object(opts, _socket) do
    Owner.notify({__MODULE__, :new_object})
    Map.get(opts, :new_object, %{})
  end

  def get_object(opts, lookup, criteria, _socket) do
    Owner.notify({__MODULE__, :get_object, lookup, criteria})
    Map.get(opts, :object)
  end

  def change_object(_opts, object, params, fields) do
    Owner.notify({__MODULE__, :change_object, object, params, Enum.map(fields, & &1.name)})
    types = Map.new(fields, &{&1.name, :string})
    Ecto.Changeset.cast({object, types}, params, Map.keys(types))
  end

  def create_object(_opts, _object, changeset) do
    Owner.notify({__MODULE__, :create_object, changeset})
    Ecto.Changeset.apply_action(changeset, :insert)
  end

  def update_object(_opts, _object, changeset) do
    Owner.notify({__MODULE__, :update_object, changeset})
    Ecto.Changeset.apply_action(changeset, :update)
  end
end
