defmodule Pax.Interface.Init do
  @moduledoc false

  def init_adapter(module, socket) do
    case module.pax_adapter(socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/1"
    end
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
