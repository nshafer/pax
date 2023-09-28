defmodule Pax.Detail.Live do
  use Phoenix.Component
  import Phoenix.LiveView
  import Pax.Util.Live

  @type field() :: Pax.Field.field()

  @callback pax_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback pax_adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback pax_fieldsets(socket :: Phoenix.LiveView.Socket.t()) ::
              list(field()) | list(list(field) | field()) | keyword(list(field)) | nil

  @callback pax_object_name(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()
  @callback pax_index_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_new_path(socket :: Phoenix.LiveView.Socket.t()) :: String.t()
  @callback pax_show_path(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()
  @callback pax_edit_path(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()

  @optional_callbacks pax_object_name: 2, pax_index_path: 1, pax_new_path: 1, pax_show_path: 2, pax_edit_path: 2

  defmacro __using__(_opts) do
    quote do
      # IO.puts("Pax.Detail.Live.__using__ for #{inspect(__MODULE__)}")
      @behaviour Pax.Detail.Live

      def on_mount(:pax_detail, params, session, socket),
        do: Pax.Detail.Live.on_mount(__MODULE__, params, session, socket)

      on_mount {__MODULE__, :pax_detail}

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def pax_adapter(_socket) do
        raise """
        No pax_adapter/1 callback found for #{__MODULE__}.
        Please configure an adapter by defining a pax_adapter function, for example:

            def pax_adapter(_socket),
              do: {Pax.Adapters.EctoSchema, repo: MyAppWeb.Repo, schema: MyApp.MyContext.MySchema}

        """
      end

      def pax_fieldsets(_socket), do: nil

      defoverridable pax_init: 3, pax_adapter: 1, pax_fieldsets: 1
    end
  end

  def on_mount(module, params, session, socket) do
    IO.puts("#{inspect(__MODULE__)}.on_mount(#{inspect(module)}, #{inspect(params)}, #{inspect(session)}")

    case module.pax_init(params, session, socket) do
      {:cont, socket} -> init(module, socket)
      {:halt, socket} -> {:halt, socket}
    end
  end

  defp init(module, socket) do
    adapter = init_adapter(module, socket)
    fieldsets = init_fieldsets(module, adapter, socket)
    # plugins = init_plugins(module, params, sessions, socket)
    plugins = []

    socket =
      socket
      |> assign_pax(:module, module)
      |> assign_pax(:adapter, adapter)
      |> assign_pax(:plugins, plugins)
      |> assign_pax(:fieldsets, fieldsets)
      |> assign_pax(:index_path, init_index_path(module, socket))
      |> assign_pax(:new_path, init_new_path(module, socket))
      |> attach_hook(:pax_handle_params, :handle_params, fn params, uri, socket ->
        on_handle_params(module, adapter, plugins, fieldsets, params, uri, socket)
      end)
      |> attach_hook(:pax_handle_event, :handle_event, fn event, params, socket ->
        on_handle_event(module, adapter, plugins, fieldsets, event, params, socket)
      end)

    {:cont, socket}
  end

  def on_handle_params(module, adapter, _plugins, fieldsets, params, uri, socket) do
    # IO.puts("#{inspect(__MODULE__)}.on_handle_params(#{module}, #{inspect(params)}, #{inspect(uri)}")
    object = init_object(module, adapter, params, uri, socket)
    object_name = init_object_name(module, adapter, socket, object)

    socket =
      socket
      |> assign_pax(:uri, URI.parse(uri))
      |> maybe_init_edit_paths(module, object)
      |> assign(:object, object)
      |> assign_pax(:object_name, object_name)
      |> maybe_assign_form(adapter, fieldsets)

    if function_exported?(module, :handle_params, 3) do
      {:cont, socket}
    else
      {:halt, socket}
    end
  end

  defp maybe_init_edit_paths(socket, module, object) do
    if socket.assigns.live_action in [:show, :edit] do
      socket
      |> assign_pax(:show_path, init_show_path(module, socket, object))
      |> assign_pax(:edit_path, init_edit_path(module, socket, object))
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
    assign(socket, form: nil)
  end

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset))
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
      |> Stream.filter(fn {_, _, opts} -> Map.get(opts, :required, true) end)
      |> Enum.map(fn {field_name, _, _} -> field_name end)

    Ecto.Changeset.validate_required(changeset, required_field_names)
  end

  defp fields_from_fieldsets(fieldsets) do
    for {_, fieldgroups} <- fieldsets, fields <- fieldgroups, field <- fields do
      field
    end
  end

  defp on_handle_event(_module, adapter, _plugins, fieldsets, "pax_validate", %{"detail" => params}, socket) do
    IO.puts("#{inspect(__MODULE__)}.on_handle_event(:pax_validate, #{inspect(params)})")

    changeset =
      changeset(adapter, fieldsets, socket.assigns.object, params)
      |> Map.put(:action, :validate)

    {:halt, assign_form(socket, changeset)}
  end

  defp on_handle_event(_module, adapter, _plugins, fieldsets, "pax_save", %{"detail" => params}, socket) do
    IO.puts("#{inspect(__MODULE__)}.on_handle_event(:pax_save, #{inspect(params)})")

    changeset = changeset(adapter, fieldsets, socket.assigns.object, params)

    save_object(socket, socket.assigns.live_action, adapter, socket.assigns.object, changeset)
  end

  # Catch-all for all other events that we don't care about
  defp on_handle_event(_module, _adapter, _plugins, _fieldsets, event, params, socket) do
    IO.puts("IGNORED: #{inspect(__MODULE__)}.on_handle_event(#{inspect(event)}, #{inspect(params)})")
    {:cont, socket}
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

  defp init_adapter(module, socket) do
    case module.pax_adapter(socket) do
      {adapter, callback_module, opts} -> Pax.Adapter.init(adapter, callback_module, opts)
      {adapter, opts} -> Pax.Adapter.init(adapter, module, opts)
      adapter when is_atom(adapter) -> Pax.Adapter.init(adapter, module, [])
      _ -> raise ArgumentError, "Invalid adapter returned from #{inspect(module)}.pax_adapter/1"
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
      case module.pax_fieldsets(socket) do
        fieldsets when is_list(fieldsets) -> fieldsets
        nil -> Pax.Adapter.default_detail_fieldsets(adapter)
        _ -> raise ArgumentError, "Invalid fieldsets returned from #{inspect(module)}.fieldsets/3"
      end

    # Check if the user returned a keyword list of fieldset name -> fieldgroups, and if not, make it :default
    if is_fieldsets?(fieldsets) do
      Enum.map(fieldsets, &init_fieldset(module, adapter, &1))
    else
      [init_fieldset(module, adapter, {:default, fieldsets})]
    end
  end

  defp is_fieldsets?(fieldsets) do
    Enum.all?(fieldsets, fn
      {name, value} when is_atom(name) and is_list(value) -> true
      _ -> false
    end)
  end

  defp init_fieldset(module, adapter, {name, fields}) when is_atom(name) and is_list(fields) do
    {name, Enum.map(fields, &init_fieldgroup(module, adapter, &1))}
  end

  # A fieldgroup can be a list of fields to display on one line, or just one field to display by itself
  defp init_fieldgroup(module, adapter, groups) when is_list(groups) do
    Enum.map(groups, &Pax.Field.init(module, adapter, &1))
  end

  defp init_fieldgroup(module, adapter, field) do
    [Pax.Field.init(module, adapter, field)]
  end
end
