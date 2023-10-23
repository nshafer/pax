defmodule Pax.Interface.Detail do
  @moduledoc false
  import Phoenix.Component, only: [assign: 3, to_form: 1]
  import Phoenix.LiveView
  import Pax.Interface.Init
  import Pax.Interface.Context
  require Logger

  def on_handle_params(module, adapter, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_params(#{module}, #{inspect(params)}, #{inspect(uri)}")
    fieldsets = init_fieldsets(module, adapter, socket)
    object = init_object(module, adapter, params, uri, socket)
    object_name = init_object_name(module, adapter, socket, object)

    socket =
      socket
      |> assign_pax(:fieldsets, fieldsets)
      |> maybe_init_detail_paths(module, object)
      |> assign(:object, object)
      |> assign_pax(:object_name, object_name)
      |> maybe_assign_form(adapter, fieldsets)

    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  def on_handle_event(_module, adapter, "pax_validate", %{"detail" => params}, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_event(:pax_validate, #{inspect(params)})")
    fieldsets = socket.assigns.pax.fieldsets

    changeset =
      changeset(adapter, fieldsets, socket.assigns.object, params)
      |> Map.put(:action, :validate)

    {:halt, assign_form(socket, changeset)}
  end

  def on_handle_event(_module, adapter, "pax_save", %{"detail" => params}, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_event(:pax_save, #{inspect(params)})")
    fieldsets = socket.assigns.pax.fieldsets

    changeset = changeset(adapter, fieldsets, socket.assigns.object, params)

    save_object(socket, socket.assigns.live_action, adapter, socket.assigns.object, changeset)
  end

  # Catch-all for all other events that we don't care about
  def on_handle_event(_module, _adapter, event, params, socket) do
    Logger.info("IGNORED: #{inspect(__MODULE__)}.on_handle_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
  end

  defp maybe_init_detail_paths(socket, module, object) do
    if socket.assigns.live_action in [:show, :edit] do
      socket
      |> assign_pax(:show_path, init_show_path(module, object, socket))
      |> assign_pax(:edit_path, init_edit_path(module, object, socket))
    else
      socket
      |> assign_pax(:show_path, nil)
      |> assign_pax(:edit_path, nil)
    end
  end

  defp init_object(_module, adapter, params, uri, socket) do
    case socket.assigns.live_action do
      action when action in [:show, :edit] -> Pax.Adapter.get_object(adapter, params, uri, socket)
      :new -> Pax.Adapter.new_object(adapter, params, uri, socket)
      _ -> nil
    end
  end

  defp maybe_assign_form(socket, adapter, fieldsets) do
    if socket.assigns.live_action in [:edit, :new] do
      changeset = changeset(adapter, fieldsets, socket.assigns.object)
      assign_form(socket, changeset)
    else
      assign_form(socket, nil)
    end
  end

  defp assign_form(socket, nil) do
    assign(socket, :form, nil)
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp changeset(adapter, fieldsets, object, params \\ %{}) do
    fields = fields_from_fieldsets(fieldsets)
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

  defp fields_from_fieldsets(fieldsets) do
    for {_, fieldgroups} <- fieldsets, fields <- fieldgroups, field <- fields do
      field
    end
  end

  defp save_object(socket, :new, adapter, object, changeset) do
    case Pax.Adapter.create_object(adapter, object, changeset) do
      {:ok, _object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Created successfully.")
          |> maybe_redir_after_save()
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:halt, assign_form(socket, changeset)}
    end
  end

  defp save_object(socket, :edit, adapter, object, changeset) do
    case Pax.Adapter.update_object(adapter, object, changeset) do
      {:ok, _object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Updated successfully.")
          |> maybe_redir_after_save()
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:halt, assign_form(socket, changeset)}
    end
  end

  defp maybe_redir_after_save(socket) do
    cond do
      socket.assigns.pax.show_path != nil -> push_patch(socket, to: socket.assigns.pax.show_path)
      socket.assigns.pax.index_path != nil -> push_navigate(socket, to: socket.assigns.pax.index_path)
      true -> socket
    end
  end

  # Fieldsets should be a Keyword list of fieldset name -> fieldgroups, where fieldgroups is a list of fields to
  # display on one line, or just one field to display by itself.
  #
  # Example:
  #
  # [
  #   default: [
  #     [name] = fields1,
  #     [email, phone] = fields2
  #   ] = fieldgroups1,
  #   metadata: [
  #     [created_at, updated_at] = fields3
  #   ] = fieldgroups2
  # ] = fieldsets

  defp init_fieldsets(module, adapter, socket) do
    fieldsets =
      case module.fieldsets(socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        nil -> Pax.Adapter.default_detail_fieldsets(adapter)
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(module)}.fieldsets/3"
      end

    # Check if the user returned a keyword list of fieldset name -> fieldgroups, and if not, make it :default
    if is_fieldsets?(fieldsets) do
      Enum.map(fieldsets, &init_fieldset(adapter, &1))
    else
      [init_fieldset(adapter, {:default, fieldsets})]
    end
  end

  defp is_fieldsets?(fieldsets) do
    Enum.all?(fieldsets, fn
      {name, value} when is_atom(name) and is_list(value) -> true
      _ -> false
    end)
  end

  defp init_fieldset(adapter, {name, fields}) when is_atom(name) and is_list(fields) do
    {name, Enum.map(fields, &init_fieldgroup(adapter, &1))}
  end

  # A fieldgroup can be a list of fields to display on one line, or just one field to display by itself
  defp init_fieldgroup(adapter, groups) when is_list(groups) do
    Enum.map(groups, &Pax.Field.init(adapter, &1))
  end

  defp init_fieldgroup(adapter, field) do
    [Pax.Field.init(adapter, field)]
  end
end
