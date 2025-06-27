defmodule Pax.Interface.Detail do
  @moduledoc false
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveView
  import Pax.Interface.Init
  import Pax.Interface.Context
  require Logger

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
    %{adapter: adapter, fields: fields, object: object} = socket.assigns.pax

    changeset =
      changeset(adapter, fields, object, params)
      |> Map.put(:action, :validate)

    {:halt, assign_pax_form(socket, changeset)}
  end

  def handle_event("pax_save", %{"detail" => params}, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_event(:pax_save, #{inspect(params)})")
    %{adapter: adapter, action: action, fields: fields, object: object} = socket.assigns.pax
    changeset = changeset(adapter, fields, object, params)
    save_object(socket, action, adapter, object, changeset)
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
    %{adapter: adapter, action: action, fields: fields, object: object} = socket.assigns.pax

    if action in [:edit, :new] do
      changeset = changeset(adapter, fields, object)
      assign_pax_form(socket, changeset)
    else
      assign_pax(socket, :form, nil)
    end
  end

  defp assign_pax_form(socket, changeset) do
    assign_pax(socket, :form, to_form(changeset, as: :detail))
  end

  defp changeset(adapter, fields, object, params \\ %{}) do
    mutable_fields = Enum.reject(fields, &Pax.Field.immutable?/1)

    Pax.Adapter.cast(adapter, object, params, mutable_fields)
    |> validate_required(mutable_fields)
  end

  defp validate_required(changeset, fields) do
    required_field_names =
      fields
      |> Stream.filter(&Pax.Field.required?/1)
      |> Enum.map(fn %Pax.Field{name: name} -> name end)

    Ecto.Changeset.validate_required(changeset, required_field_names)
  end

  defp save_object(socket, :new, adapter, object, changeset) do
    case Pax.Adapter.create_object(adapter, object, changeset) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Created successfully.")
          |> maybe_redir_after_save(object)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:halt, assign_pax_form(socket, changeset)}
    end
  end

  defp save_object(socket, :edit, adapter, object, changeset) do
    case Pax.Adapter.update_object(adapter, object, changeset) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Updated successfully.")
          |> maybe_redir_after_save(object)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:halt, assign_pax_form(socket, changeset)}
    end
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
