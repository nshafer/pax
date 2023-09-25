defmodule Pax.Util.Live do
  @moduledoc false

  # Utility functions for the Index and Detail live views
  import Phoenix.Component, only: [assign: 3]

  def assign_pax(socket_or_assigns, key, value)

  def assign_pax(%Phoenix.LiveView.Socket{} = socket, key, value) do
    pax =
      socket.assigns
      |> Map.get(:pax, %{})
      |> Map.put(key, value)

    assign(socket, :pax, pax)
  end

  def assign_pax(%{} = assigns, key, value) do
    pax =
      assigns
      |> Map.get(:pax, %{})
      |> Map.put(key, value)

    assign(assigns, :pax, pax)
  end

  def assign_pax(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax(acc, key, value)
    end)
  end

  def init_singular_name(module, adapter, socket) do
    if function_exported?(module, :pax_singular_name, 1) do
      module.pax_singular_name(socket)
    else
      Pax.Adapter.singular_name(adapter)
    end
  end

  def init_plural_name(module, adapter, socket) do
    if function_exported?(module, :pax_plural_name, 1) do
      module.pax_plural_name(socket)
    else
      Pax.Adapter.plural_name(adapter)
    end
  end

  def init_object_name(_module, _adapter, _socket, nil), do: "Object"

  def init_object_name(module, adapter, socket, object) do
    if function_exported?(module, :pax_object_name, 2) do
      module.pax_object_name(socket, object)
    else
      Pax.Adapter.object_name(adapter, object)
    end
  end

  def init_index_path(module, socket) do
    if function_exported?(module, :pax_index_path, 1) do
      module.pax_index_path(socket)
    else
      nil
    end
  end

  def init_new_path(module, socket) do
    if function_exported?(module, :pax_new_path, 1) do
      module.pax_new_path(socket)
    else
      nil
    end
  end

  def init_show_path(module, socket, object) do
    if function_exported?(module, :pax_show_path, 2) do
      module.pax_show_path(socket, object)
    else
      nil
    end
  end

  def init_edit_path(module, socket, object) do
    if function_exported?(module, :pax_edit_path, 2) do
      module.pax_edit_path(socket, object)
    else
      nil
    end
  end
end
