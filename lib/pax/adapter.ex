defmodule Pax.Adapter do
  @moduledoc """
  The behaviour for adapters, which load and persist objects for a `Pax.Interface`.

  An adapter is configured with `pax_adapter/1` (or `adapter/1` in a `Pax.Admin.Resource`):

      def pax_adapter(_socket) do
        {Pax.Adapters.EctoSchema, repo: MyApp.Repo, schema: MyApp.MySchema}
      end

  Pax calls the callback module first for every data operation, and falls back to the adapter when the module
  returns `:not_implemented`. With neither, it raises.

  ## The socket, and what is on it

  Every data callback receives the socket as its last argument. `socket.assigns.pax` is a `%Pax.Interface{}`, so
  an adapter can read anything the interface has already worked out for this request, including:

    * `fields` - the `Pax.Field` structs for the current action, which is how an adapter knows what to cast
    * `object` - the object being shown or edited
    * `action` - `:index`, `:show`, `:new`, `:edit` or `:delete`
    * `criteria` - the map the data layer is being asked to apply
    * `config` - the validated `Pax.Config` map

  See `Pax.Interface` for the full list. Because these are read per call, they are always current.

  ## Per-call values from the host

  An adapter that needs a value only the host can supply - an actor to authorize with, a tenant to scope to, a
  `Phoenix.LiveView` scope - declares the key in its own `c:config_spec/1` and resolves it per call:

      def config_spec(_opts) do
        %{actor: [:any, {:function, 1, :any}]}
      end

      defp actor(socket) do
        %{config: config} = socket.assigns.pax
        Pax.Config.get(config, [:adapter, :actor], [socket], nil)
      end

  The host then writes it once, as a literal or as a function of the socket:

      def pax_config(_socket) do
        [adapter: [actor: & &1.assigns.current_user]]
      end

  Resolve such values per call, **not** in `c:merge_config/3`. That runs once while the interface is built, so a
  value captured there freezes at mount - which is wrong for anything that can change inside one socket, such as
  a current user re-read on resume or an operator switching tenant. Use `c:merge_config/3` only for configuration
  of the resource itself, such as the repo and schema in `Pax.Adapters.EctoSchema`.

  ## Options versus config

  The `opts` given in `{MyAdapter, opts}` are fixed when the adapter is initialized, and Pax passes them to
  `c:init/2` unchanged - validating them is the adapter's own business, which every built-in adapter does with
  `Pax.Options.validate!/3`. Configuration that must be resolved per socket goes through `Pax.Config` instead,
  under the `:adapter` key, as above.
  """

  alias Pax.Interface

  @type adapter_module :: module
  @type callback_module :: module

  defstruct [:module, :opts]

  @type t :: %__MODULE__{}

  @type opts ::
          binary()
          | tuple()
          | atom()
          | integer()
          | float()
          | [opts()]
          | %{optional(opts()) => opts()}
          | MapSet.t()

  @type lookup :: %{atom() => any()}
  @type criteria :: %{atom() => any()}

  @typedoc "A Phoenix.LiveView socket"
  @type socket :: Phoenix.LiveView.Socket.t()

  @typedoc "Unsigned params from a Phoenix.LiveView handle_params/3"
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()

  @typedoc """
  A data-layer-owned value that a form is built from, which must implement `Phoenix.HTML.FormData`.

  Pax treats it as opaque: it builds a form from it, keeps it in `@pax.form_data`, and hands it back to the
  adapter. `Pax.Adapters.EctoSchema` uses an `Ecto.Changeset`; an Ash adapter uses an `AshPhoenix.Form`.
  """
  @type form_data :: term()

  @doc """
  The adapter initialization function, must return a map of initialized adapter state.

  The `opts` are passed through as the developer gave them in `{MyAdapter, opts}`. Validate them with
  `Pax.Options.validate!/3` if you want them checked, which is what `Pax.Adapters.EctoSchema` does.
  """
  @callback init(callback_module, opts :: []) :: opts()

  @doc "A function that returns a valid Pax.Config spec for configuration keys and types accepted by the adapter."
  @callback config_spec(opts()) :: map()

  @doc "A function that merges any additional configuration options into the adapter's opts map."
  @callback merge_config(opts(), config :: map(), socket()) :: map()

  @callback default_fields(opts()) :: Pax.Index.fields()

  @callback field_type(opts(), field_name :: atom()) ::
              {:ok, atom() | module()} | {:error, term()}

  @callback singular_name(opts()) :: String.t()

  @callback plural_name(opts()) :: String.t()

  @callback count_objects(opts(), criteria(), socket()) :: integer()

  @callback list_objects(opts(), criteria(), socket()) :: [Interface.object()]

  @callback new_object(opts(), socket()) :: Interface.object()

  @callback get_object(opts(), lookup(), criteria(), socket()) :: Interface.object()

  @callback id_fields(opts()) :: [atom()] | nil

  @callback object_ids(opts(), Interface.object()) :: [String.Chars.t()] | nil

  @callback object_name(opts(), Interface.object()) :: String.t() | nil

  @doc """
  Builds the form data for a new or edit page, for the given object.

  Pax keeps the returned value in `@pax.form_data` and hands it back to `c:validate_object/5`,
  `c:create_object/5` and `c:update_object/5`, so a stateful form type survives a whole edit. It must be named
  with `form_name/0`, or the events Pax sends will not match it.
  """
  @callback change_object(opts(), Interface.object(), socket()) :: form_data()

  @doc """
  Applies the submitted params to the form data, for rendering with any resulting errors.

  This is where a data layer marks its form as validated, if it needs to. An adapter whose form data carries
  state should apply the params to the value it was handed; one whose form data is a pure function of its inputs,
  such as an `Ecto.Changeset`, should ignore it and rebuild from `object`.
  """
  @callback validate_object(opts(), Interface.object(), form_data(), unsigned_params(), socket()) :: form_data()

  @doc """
  Persists a new object from the submitted params.

  The form data is the value Pax is holding, which may carry state from an earlier validate or a failed submit.
  Rebuild from `object` rather than mutating it unless the data layer requires otherwise.
  """
  @callback create_object(opts(), Interface.object(), form_data(), unsigned_params(), socket()) ::
              {:ok, Interface.object()} | {:error, form_data()}

  @doc "Persists changes to an existing object from the submitted params. See `c:create_object/5`."
  @callback update_object(opts(), Interface.object(), form_data(), unsigned_params(), socket()) ::
              {:ok, Interface.object()} | {:error, form_data()}

  @spec init(module(), opts :: []) :: t()
  def init(adapter_module, callback_module, opts \\ []) do
    %Pax.Adapter{
      module: adapter_module,
      opts: adapter_module.init(callback_module, opts)
    }
  end

  @spec adapter?(term()) :: boolean()
  def adapter?(%Pax.Adapter{}), do: true
  def adapter?(_), do: false

  @spec config_spec(t()) :: map()
  def config_spec(%Pax.Adapter{} = adapter) do
    adapter.module.config_spec(adapter.opts)
  end

  def merge_config(%Pax.Adapter{} = adapter, config, socket) do
    opts = adapter.module.merge_config(adapter.opts, config, socket)
    %Pax.Adapter{adapter | opts: opts}
  end

  @spec default_fields(t()) :: Pax.Index.fields()
  def default_fields(%Pax.Adapter{} = adapter) do
    adapter.module.default_fields(adapter.opts)
  end

  @spec field_type!(t(), field_name :: atom()) :: atom()
  def field_type!(%Pax.Adapter{} = adapter, field_name) do
    case adapter.module.field_type(adapter.opts, field_name) do
      {:ok, field_type} -> field_type
      {:error, error} -> raise error
    end
  end

  # TODO: Make this always return a list, return [:id] if adapter returns nil. Remove `init_adapter_id_fields`
  @spec id_fields(t()) :: [atom()] | nil
  def id_fields(%Pax.Adapter{} = adapter) do
    adapter.module.id_fields(adapter.opts)
  end

  @spec object_ids(t(), Interface.object()) :: [String.Chars.t()]
  def object_ids(%Pax.Adapter{} = adapter, object) do
    case adapter.module.object_ids(adapter.opts, object) do
      nil -> default_object_ids(adapter, object)
      ids when is_list(ids) -> ids
      _ -> raise ArgumentError, "object_ids must return a list or nil"
    end
  end

  # TODO: Make this always return a string, return "Object" if adapter returns nil. Remove `init_adapter_singular_name`
  @spec singular_name(t()) :: String.t() | nil
  def singular_name(%Pax.Adapter{} = adapter) do
    adapter.module.singular_name(adapter.opts)
  end

  # TODO: Make this always return a string, return "Objects" if adapter returns nil. Remove `init_adapter_plural_name`
  @spec plural_name(t()) :: String.t() | nil
  def plural_name(%Pax.Adapter{} = adapter) do
    adapter.module.plural_name(adapter.opts)
  end

  @spec count_objects(t(), criteria(), socket()) :: integer()
  def count_objects(%Pax.Adapter{} = adapter, criteria, socket) do
    adapter.module.count_objects(adapter.opts, criteria, socket)
  end

  @spec list_objects(t(), criteria(), socket()) :: [Interface.object()]
  def list_objects(%Pax.Adapter{} = adapter, criteria, socket) do
    adapter.module.list_objects(adapter.opts, criteria, socket)
  end

  @spec new_object(t(), socket()) :: Interface.object()
  def new_object(%Pax.Adapter{} = adapter, socket) do
    adapter.module.new_object(adapter.opts, socket)
  end

  @spec get_object(t(), lookup(), criteria(), socket()) :: Interface.object()
  def get_object(%Pax.Adapter{} = adapter, lookup, criteria, socket) do
    adapter.module.get_object(adapter.opts, lookup, criteria, socket)
  end

  # TODO: Make this always return a string, return nil if adapter returns nil. Remove `init_adapter_object_name`
  @spec object_name(t(), Interface.object()) :: String.t() | nil
  def object_name(%Pax.Adapter{} = adapter, object) do
    adapter.module.object_name(adapter.opts, object)
  end

  @doc "The name Pax builds detail forms under, which form data must use so that form events match."
  @spec form_name() :: atom()
  def form_name(), do: :detail

  @spec change_object(t(), Interface.object(), socket()) :: form_data()
  def change_object(%Pax.Adapter{} = adapter, object, socket) do
    adapter.module.change_object(adapter.opts, object, socket)
  end

  @spec validate_object(t(), Interface.object(), form_data(), unsigned_params(), socket()) :: form_data()
  def validate_object(%Pax.Adapter{} = adapter, object, form_data, params, socket) do
    adapter.module.validate_object(adapter.opts, object, form_data, params, socket)
  end

  @spec create_object(t(), Interface.object(), form_data(), unsigned_params(), socket()) ::
          {:ok, Interface.object()} | {:error, form_data()}
  def create_object(%Pax.Adapter{} = adapter, object, form_data, params, socket) do
    adapter.module.create_object(adapter.opts, object, form_data, params, socket)
  end

  @spec update_object(t(), Interface.object(), form_data(), unsigned_params(), socket()) ::
          {:ok, Interface.object()} | {:error, form_data()}
  def update_object(%Pax.Adapter{} = adapter, object, form_data, params, socket) do
    adapter.module.update_object(adapter.opts, object, form_data, params, socket)
  end

  defp default_object_ids(adapter, object) do
    case id_fields(adapter) do
      nil -> []
      id_fields -> Enum.map(id_fields, fn field -> Map.fetch!(object, field) end)
    end
  end
end
