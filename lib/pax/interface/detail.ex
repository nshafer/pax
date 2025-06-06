defmodule Pax.Interface.Detail do
  @moduledoc false
  import Phoenix.Component, only: [to_form: 2]
  import Phoenix.LiveView
  import Pax.Interface.Init
  import Pax.Interface.Context
  require Logger

  alias Pax.Config

  def handle_params(params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.handle_params(#{inspect(params)}, #{inspect(uri)}")
    # dbg(socket, structs: false)

    object = init_object(params, uri, socket)
    object_name = init_object_name(object, socket)

    socket =
      socket
      |> assign_pax(:object, object)
      |> assign_pax(:object_name, object_name)
      |> maybe_init_detail_paths(object)
      |> maybe_assign_form(object)

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
    %{config: config, adapter: adapter, action: action, fields: fields, object: object} = socket.assigns.pax
    changeset = changeset(adapter, fields, object, params)
    save_object(socket, action, config, adapter, object, changeset)
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

  defp maybe_init_detail_paths(socket, object) do
    %{config: config, action: action} = socket.assigns.pax

    if action in [:show, :edit] do
      socket
      |> assign_pax(:show_path, init_show_path(config, object, socket))
      |> assign_pax(:edit_path, init_edit_path(config, object, socket))
    else
      socket
      |> assign_pax(:show_path, nil)
      |> assign_pax(:edit_path, nil)
    end
  end

  defp init_object(params, uri, socket) do
    %{adapter: adapter, action: action, scope: scope} = socket.assigns.pax

    case action do
      action when action in [:show, :edit] ->
        lookup = init_lookup(params, uri, socket)
        Pax.Adapter.get_object(adapter, lookup, scope, socket)

      :new ->
        Pax.Adapter.new_object(adapter, socket)

      _ ->
        nil
    end
  end

  defp init_lookup(params, uri, socket) do
    %{config: config} = socket.assigns.pax

    # Check if the user has defined a `:lookup` config option, which can only be a function, and call it.
    # Otherwise, construct a lookup map using config, the adapter, and some sensible defaults.
    case Config.fetch(config, :lookup, [params, uri, socket]) do
      {:ok, value} -> value
      :error -> construct_lookup_map(params, socket)
    end
  end

  defp construct_lookup_map(params, socket) do
    %{config: config, adapter: adapter} = socket.assigns.pax

    # Get the list of params, which could be individually specified as `lookup_params` or a list of strings from
    # `lookup_glob` depending on how they configured their router.
    param_values = lookup_params(params, socket)

    # Get the list of id fields for the object, which should be a list of atoms. If none are defined in the config,
    # then use the adapter to figure out a default. If the adapter can't help then just use a default.
    id_fields =
      case Config.fetch(config, :id_fields, [socket]) do
        {:ok, value} ->
          value

        :error ->
          case Pax.Adapter.id_fields(adapter) do
            nil -> Pax.Interface.Config.default_id_fields()
            fields -> fields
          end
      end

    # Make sure that the number of lookup params matches the number of id fields
    if length(param_values) != length(id_fields) do
      raise ArgumentError, "The number of params must match the number of id_fields"
    end

    # Zip the id fields with the param values to create a map of id field -> param value
    Enum.zip_reduce(id_fields, param_values, %{}, fn id_field, param_value, acc ->
      if not is_atom(id_field) do
        raise ArgumentError, "id_fields must be a list of atoms, got #{inspect(id_field)}"
      end

      Map.put(acc, id_field, param_value)
    end)
  end

  defp lookup_params(params, socket) do
    %{config: config} = socket.assigns.pax

    lookup_params = Config.get(config, :lookup_params, [socket])
    lookup_glob = Config.get(config, :lookup_glob, [socket])

    cond do
      lookup_params != nil and lookup_glob != nil ->
        raise ArgumentError, "You can't define both :lookup_params and :lookup_glob in the config"

      lookup_params != nil ->
        fetch_lookup_params(lookup_params, params)

      lookup_glob != nil ->
        fetch_lookup_glob(lookup_glob, params)

      true ->
        Pax.Interface.Config.default_lookup_params() |> fetch_lookup_params(params)
    end
  end

  defp fetch_lookup_params(lookup_params, params) do
    for lookup_param <- lookup_params do
      case Map.fetch(params, to_string(lookup_param)) do
        {:ok, value} -> value
        :error -> raise ArgumentError, "Missing param: #{lookup_param}"
      end
    end
  end

  defp fetch_lookup_glob(lookup_glob, params) do
    case Map.fetch(params, lookup_glob) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "Missing param: #{lookup_glob}"
    end
  end

  defp maybe_assign_form(socket, object) do
    %{adapter: adapter, action: action, fields: fields} = socket.assigns.pax

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

  defp save_object(socket, :new, config, adapter, object, changeset) do
    case Pax.Adapter.create_object(adapter, object, changeset) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Created successfully.")
          |> maybe_redir_after_save(config, object)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:halt, assign_pax_form(socket, changeset)}
    end
  end

  defp save_object(socket, :edit, config, adapter, object, changeset) do
    case Pax.Adapter.update_object(adapter, object, changeset) do
      {:ok, object} ->
        {
          :halt,
          socket
          |> put_flash(:info, "Updated successfully.")
          |> maybe_redir_after_save(config, object)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:halt, assign_pax_form(socket, changeset)}
    end
  end

  defp maybe_redir_after_save(socket, config, object) do
    %{index_path: index_path} = socket.assigns.pax

    # Update paths with new object
    show_path = init_show_path(config, object, socket)
    edit_path = init_edit_path(config, object, socket)

    socket =
      socket
      |> assign_pax(:show_path, show_path)
      |> assign_pax(:edit_path, edit_path)

    # Redirect to the proper path after saving, or just stay on the page if no path is defined (weird)
    cond do
      show_path != nil -> push_patch(socket, to: show_path)
      index_path != nil -> push_navigate(socket, to: index_path)
      true -> socket
    end
  end
end
