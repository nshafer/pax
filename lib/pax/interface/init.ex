defmodule Pax.Interface.Init do
  @moduledoc false

  def init_adapter(module, socket) do
    case module.adapter(socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.adapter/1"
    end
  end

  def init_singular_name(module, adapter, socket) do
    if function_exported?(module, :singular_name, 1) do
      module.singular_name(socket)
    else
      Pax.Adapter.singular_name(adapter)
    end
  end

  def init_plural_name(module, adapter, socket) do
    if function_exported?(module, :plural_name, 1) do
      module.plural_name(socket)
    else
      Pax.Adapter.plural_name(adapter)
    end
  end

  def init_index_path(module, socket) do
    if function_exported?(module, :index_path, 1) do
      module.index_path(socket)
    else
      nil
    end
  end

  def init_new_path(module, socket) do
    if function_exported?(module, :new_path, 1) do
      module.new_path(socket)
    else
      nil
    end
  end

  def init_show_path(module, object, socket) do
    if function_exported?(module, :show_path, 2) do
      module.show_path(object, socket)
    else
      nil
    end
  end

  def init_edit_path(module, object, socket) do
    if function_exported?(module, :edit_path, 2) do
      module.edit_path(object, socket)
    else
      nil
    end
  end
end
