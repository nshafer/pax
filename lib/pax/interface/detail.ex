defmodule Pax.Interface.Detail do
  @moduledoc false
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveView
  import Pax.Interface.Init
  import Pax.Interface
  require Logger

  @callback new_object(socket :: Phoenix.LiveView.Socket.t()) :: Pax.Interface.object()
  @callback get_object(lookup :: map(), criteria :: map(), socket :: Phoenix.LiveView.Socket.t()) ::
              Pax.Interface.object()
  @callback change_object(
              object :: Pax.Interface.object(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: Pax.Adapter.form_data()
  @callback validate_object(
              object :: Pax.Interface.object(),
              form_data :: Pax.Adapter.form_data(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: Pax.Adapter.form_data()
  @callback create_object(
              object :: Pax.Interface.object(),
              form_data :: Pax.Adapter.form_data(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Pax.Adapter.form_data()}
  @callback update_object(
              object :: Pax.Interface.object(),
              form_data :: Pax.Adapter.form_data(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Pax.Adapter.form_data()}

  @optional_callbacks [
    new_object: 1,
    get_object: 3,
    change_object: 2,
    validate_object: 4,
    create_object: 4,
    update_object: 4
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Interface.Detail

      def new_object(_socket), do: :not_implemented
      def get_object(_lookup, _criteria, _socket), do: :not_implemented
      def change_object(_object, _socket), do: :not_implemented
      def validate_object(_object, _form_data, _params, _socket), do: :not_implemented
      def create_object(_object, _form_data, _params, _socket), do: :not_implemented
      def update_object(_object, _form_data, _params, _socket), do: :not_implemented

      defoverridable new_object: 1,
                     get_object: 3,
                     change_object: 2,
                     validate_object: 4,
                     create_object: 4,
                     update_object: 4
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
    %{object: object, form_data: form_data} = socket.assigns.pax

    {:halt, assign_pax_form(socket, validate_object(object, form_data, params, socket))}
  end

  def handle_event("pax_save", %{"detail" => params}, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_event(:pax_save, #{inspect(params)})")
    %{action: action, object: object, form_data: form_data} = socket.assigns.pax

    save_object(action, object, form_data, params, socket)
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
    %{action: action, object: object} = socket.assigns.pax

    if action in [:edit, :new] do
      assign_pax_form(socket, change_object(object, socket))
    else
      assign_pax(socket, form: nil, form_data: nil)
    end
  end

  # The only writer of :form and :form_data, so the two cannot drift apart.
  defp assign_pax_form(socket, form_data) do
    assign_pax(socket, form_data: form_data, form: to_form(form_data, as: Pax.Adapter.form_name()))
  end

  defp change_object(object, socket) do
    %{module: module, adapter: adapter} = socket.assigns.pax

    case module.change_object(object, socket) do
      :not_implemented -> adapter_change_object(adapter, object, socket)
      form_data -> check_form_data!(form_data, "change_object/2")
    end
  end

  defp adapter_change_object(nil, _object, _socket) do
    raise "Could not change the object. You must either define " <>
            "a `change_object/2` callback, or configure a Pax.Adapter."
  end

  defp adapter_change_object(adapter, object, socket) do
    adapter
    |> Pax.Adapter.change_object(object, socket)
    |> check_form_data!("#{inspect(adapter.module)}.change_object/3")
  end

  defp validate_object(object, form_data, params, socket) do
    %{module: module, adapter: adapter} = socket.assigns.pax

    case module.validate_object(object, form_data, params, socket) do
      :not_implemented -> adapter_validate_object(adapter, object, form_data, params, socket)
      new_form_data -> check_form_data!(new_form_data, "validate_object/4")
    end
  end

  defp adapter_validate_object(nil, _object, _form_data, _params, _socket) do
    raise "Could not validate the object. You must either define " <>
            "a `validate_object/4` callback, or configure a Pax.Adapter."
  end

  defp adapter_validate_object(adapter, object, form_data, params, socket) do
    adapter
    |> Pax.Adapter.validate_object(object, form_data, params, socket)
    |> check_form_data!("#{inspect(adapter.module)}.validate_object/5")
  end

  defp save_object(:new, object, form_data, params, socket) do
    case create_object(object, form_data, params, socket) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Created successfully.")
          |> maybe_redir_after_save(object)
        }

      {:error, form_data} ->
        Logger.debug("Create error: #{inspect(form_data)}")
        {:halt, assign_pax_form(socket, form_data)}
    end
  end

  defp save_object(:edit, object, form_data, params, socket) do
    case update_object(object, form_data, params, socket) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Updated successfully.")
          |> maybe_redir_after_save(object)
        }

      {:error, form_data} ->
        Logger.debug("Update error: #{inspect(form_data)}")
        {:halt, assign_pax_form(socket, form_data)}
    end
  end

  defp create_object(object, form_data, params, socket) do
    %{module: module, adapter: adapter} = socket.assigns.pax

    case module.create_object(object, form_data, params, socket) do
      :not_implemented -> adapter_create_object(adapter, object, form_data, params, socket)
      result -> check_save_result!(result, "create_object/4")
    end
  end

  defp adapter_create_object(nil, _object, _form_data, _params, _socket) do
    raise "Could not create the object. You must either define " <>
            "a `create_object/4` callback, or configure a Pax.Adapter."
  end

  defp adapter_create_object(adapter, object, form_data, params, socket) do
    adapter
    |> Pax.Adapter.create_object(object, form_data, params, socket)
    |> check_save_result!("#{inspect(adapter.module)}.create_object/5")
  end

  defp update_object(object, form_data, params, socket) do
    %{module: module, adapter: adapter} = socket.assigns.pax

    case module.update_object(object, form_data, params, socket) do
      :not_implemented -> adapter_update_object(adapter, object, form_data, params, socket)
      result -> check_save_result!(result, "update_object/4")
    end
  end

  defp adapter_update_object(nil, _object, _form_data, _params, _socket) do
    raise "Could not update the object. You must either define " <>
            "a `update_object/4` callback, or configure a Pax.Adapter."
  end

  defp adapter_update_object(adapter, object, form_data, params, socket) do
    adapter
    |> Pax.Adapter.update_object(object, form_data, params, socket)
    |> check_save_result!("#{inspect(adapter.module)}.update_object/5")
  end

  # Pax only needs to build a form from the value, so Phoenix.HTML.FormData is the whole requirement. Checking
  # for a struct from one data layer would reject every other one.
  defp check_form_data!(form_data, function) do
    if Phoenix.HTML.FormData.impl_for(form_data) do
      form_data
    else
      raise "#{function} must return a value that implements Phoenix.HTML.FormData, got: #{inspect(form_data)}"
    end
  end

  defp check_save_result!(result, function) do
    case result do
      {:ok, object} when is_map(object) ->
        {:ok, object}

      {:error, form_data} = error ->
        if Phoenix.HTML.FormData.impl_for(form_data),
          do: error,
          else: raise_save_result!(result, function)

      other ->
        raise_save_result!(other, function)
    end
  end

  defp raise_save_result!(result, function) do
    raise "#{function} must return {:ok, object} or {:error, form_data}, got: #{inspect(result)}"
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
