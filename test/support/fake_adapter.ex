defmodule PaxTest.FakeAdapter do
  @moduledoc """
  A Pax.Adapter whose answers are given as init opts, for testing how Pax uses adapters.

  Each callback returns the opt of the same name (or a default), and data callbacks report to the owning test. The
  `:results` opt is a map of data callback names to values to return instead, such as invalid values.
  """
  @behaviour Pax.Adapter

  alias PaxTest.Owner

  def init(callback_module, opts), do: opts |> Map.new() |> Map.put(:callback_module, callback_module)

  # `fake_key` is resource config, folded into opts at init. `per_call_key` is resolved per call instead, the
  # way a real adapter resolves an actor or tenant - it can read things that do not exist yet at init.
  def config_spec(_opts) do
    %{fake_key: [:string, {:function, 1, :string}], per_call_key: [:string, {:function, 1, :string}]}
  end

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

  def count_objects(opts, criteria, socket) do
    Owner.notify({__MODULE__, :count_objects, criteria, per_call_config(socket)})
    result(opts, :count_objects, fn -> length(Map.get(opts, :objects, [])) end)
  end

  def list_objects(opts, criteria, socket) do
    Owner.notify({__MODULE__, :list_objects, criteria, per_call_config(socket)})
    result(opts, :list_objects, fn -> Map.get(opts, :objects, []) end)
  end

  def new_object(opts, _socket) do
    Owner.notify({__MODULE__, :new_object})
    Map.get(opts, :new_object, %{})
  end

  def get_object(opts, lookup, criteria, _socket) do
    Owner.notify({__MODULE__, :get_object, lookup, criteria})
    Map.get(opts, :object)
  end

  def change_object(opts, object, params, fields) do
    Owner.notify({__MODULE__, :change_object, object, params, Enum.map(fields, & &1.name)})

    result(opts, :change_object, fn ->
      types = Map.new(fields, &{&1.name, :string})
      Ecto.Changeset.cast({object, types}, params, Map.keys(types))
    end)
  end

  def create_object(opts, _object, changeset) do
    Owner.notify({__MODULE__, :create_object, changeset})
    result(opts, :create_object, fn -> Ecto.Changeset.apply_action(changeset, :insert) end)
  end

  def update_object(opts, _object, changeset) do
    Owner.notify({__MODULE__, :update_object, changeset})
    result(opts, :update_object, fn -> Ecto.Changeset.apply_action(changeset, :update) end)
  end

  # Resolves a config value per call from the socket, the way a real adapter resolves an actor or tenant.
  defp per_call_config(socket) do
    %{config: config} = socket.assigns.pax
    Pax.Config.get(config, [:adapter, :per_call_key], [socket], nil)
  end

  defp result(opts, callback, default) do
    case Map.fetch(Map.get(opts, :results, %{}), callback) do
      {:ok, value} -> value
      :error -> default.()
    end
  end
end
