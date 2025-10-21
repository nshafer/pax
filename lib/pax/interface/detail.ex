defmodule Pax.Interface.Detail do
  @moduledoc false
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveView
  import Pax.Interface.Init
  import Pax.Interface
  require Logger

  @callback new_object(socket :: Phoenix.LiveView.Socket.t()) :: Pax.Interface.object()
  @callback get_object(lookup :: map(), scope :: map(), socket :: Phoenix.LiveView.Socket.t()) :: Pax.Interface.object()
  @callback change_object(
              object :: Pax.Interface.object(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: Ecto.Changeset.t()
  @callback create_object(
              object :: Pax.Interface.object(),
              changeset :: Ecto.Changeset.t(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Ecto.Changeset.t()}
  @callback update_object(
              object :: Pax.Interface.object(),
              changeset :: Ecto.Changeset.t(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Ecto.Changeset.t()}

  @optional_callbacks [
    new_object: 1,
    get_object: 3,
    change_object: 3,
    create_object: 4,
    update_object: 4
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Interface.Detail

      def new_object(_socket), do: :not_implemented
      def get_object(_lookup, _scope, _socket), do: :not_implemented
      def change_object(_object, _params, _socket), do: :not_implemented
      def create_object(_object, _changeset, _params, _socket), do: :not_implemented
      def update_object(_object, _changeset, _params, _socket), do: :not_implemented

      defoverridable new_object: 1, get_object: 3, change_object: 3, create_object: 4, update_object: 4
    end
  end

  def handle_params(params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(params)}, #{inspect(uri)}")

    socket =
      socket
      |> assign_object(params, uri)
      |> assign_object_name()
      |> assign_pax(:index_query, params["index_query"])
      |> assign_show_path()
      |> assign_edit_path()
      |> maybe_assign_form()

    {:cont, socket}
  end

  def handle_event("pax_validate", %{"detail" => params}, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_event(:pax_validate, #{inspect(params)})")
    %{module: module, adapter: adapter, object: object} = socket.assigns.pax

    changeset =
      change_object(module, adapter, object, params, socket)
      |> Map.put(:action, :validate)

    {:halt, assign_pax_form(socket, changeset)}
  end

  def handle_event("pax_save", %{"detail" => params}, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_event(:pax_save, #{inspect(params)})")
    %{module: module, adapter: adapter, action: action, object: object} = socket.assigns.pax
    changeset = change_object(module, adapter, object, params, socket)
    save_object(module, adapter, action, object, changeset, params, socket)
  end

  # Catch-all for all other events that we don't care about
  def handle_event(_event, _params, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.handle_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
  end

  # Catch-all for all other info messages that we don't care about
  def handle_info(_msg, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.handle_info(#{inspect(msg)})")
    {:cont, socket}
  end

  # Catch-all for all other async results that we don't care about
  def handle_async(_name, _return, socket) do
    # Logger.debug("IGNORED: #{inspect(__MODULE__)}.handle_async(#{inspect(name)})")
    {:cont, socket}
  end

  # Do things after rendering the live view, but this will not trigger a rerender.
  def after_render(socket) do
    # Logger.debug("#{inspect(__MODULE__)}.after_render()")
    socket
  end

  defp maybe_assign_form(socket) do
    %{module: module, adapter: adapter, action: action, object: object} = socket.assigns.pax

    if action in [:edit, :new] do
      changeset = change_object(module, adapter, object, %{}, socket)
      assign_pax_form(socket, changeset)
    else
      assign_pax(socket, :form, nil)
    end
  end

  defp assign_pax_form(socket, changeset) do
    assign_pax(socket, :form, to_form(changeset, as: :detail))
  end

  defp change_object(module, adapter, object, params, socket) do
    case module.change_object(object, params, socket) do
      :not_implemented -> adapter_change_object(adapter, object, params, socket)
      %Ecto.Changeset{} = changeset -> changeset
      other -> raise "change_object/3 must return an Ecto.Changeset, got: #{inspect(other)}"
    end
  end

  defp adapter_change_object(nil, _object, _params, _socket) do
    raise "Could not change the object. You must either define " <>
            "a `change_object/3` callback, or configure a Pax.Adapter."
  end

  defp adapter_change_object(adapter, object, params, socket) do
    %{fields: fields} = socket.assigns.pax
    Pax.Adapter.change_object(adapter, object, params, fields)
  end

  defp save_object(module, adapter, :new, object, changeset, params, socket) do
    case create_object(module, adapter, object, changeset, params, socket) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Created successfully.")
          |> maybe_redir_after_save(object)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.debug("Create error: #{inspect(changeset)}")
        {:halt, assign_pax_form(socket, changeset)}
    end
  end

  defp save_object(module, adapter, :edit, object, changeset, params, socket) do
    case update_object(module, adapter, object, changeset, params, socket) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Updated successfully.")
          |> maybe_redir_after_save(object)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.debug("Update error: #{inspect(changeset)}")
        {:halt, assign_pax_form(socket, changeset)}
    end
  end

  defp create_object(module, adapter, object, changeset, params, socket) do
    case module.create_object(object, changeset, params, socket) do
      :not_implemented -> adapter_create_object(adapter, object, changeset, params)
      {:ok, object} when is_map(object) -> {:ok, object}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      other -> raise "create_object/4 must return {:ok, object} or {:error, changeset}, got: #{inspect(other)}"
    end
  end

  defp adapter_create_object(nil, _object, _changeset, _params) do
    raise "Could not create the object. You must either define " <>
            "a `create_object/4` callback, or configure a Pax.Adapter."
  end

  defp adapter_create_object(adapter, object, changeset, params) do
    Pax.Adapter.create_object(adapter, object, changeset, params)
  end

  defp update_object(module, adapter, object, changeset, params, socket) do
    case module.update_object(object, changeset, params, socket) do
      :not_implemented -> adapter_update_object(adapter, object, changeset, params)
      {:ok, object} when is_map(object) -> {:ok, object}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      other -> raise "update_object/4 must return {:ok, object} or {:error, changeset}, got: #{inspect(other)}"
    end
  end

  defp adapter_update_object(nil, _object, _params, _changeset) do
    raise "Could not update the object. You must either define " <>
            "a `update_object/4` callback, or configure a Pax.Adapter."
  end

  defp adapter_update_object(adapter, object, changeset, params) do
    Pax.Adapter.update_object(adapter, object, changeset, params)
  end

  defp maybe_redir_after_save(socket, object) do
    %{index_path: index_path} = socket.assigns.pax

    # Update paths with new object
    socket = assign_pax(socket, :object, object)
    show_path = init_show_path(socket)
    edit_path = init_edit_path(socket)

    socket =
      socket
      |> assign_pax(:show_path, show_path)
      |> assign_pax(:edit_path, edit_path)

    # Redirect to the proper path after saving
    cond do
      show_path != nil -> push_patch(socket, to: show_path)
      index_path != nil -> push_navigate(socket, to: index_path)
      edit_path != nil -> push_patch(socket, to: edit_path)
      true -> raise "Could not determine path to redirect after save"
    end
  end
end
