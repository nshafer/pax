defmodule Pax.Interface.Context do
  @moduledoc """
  The Pax Interface Context contains information on how to build the page; Accessed with `@pax` in templates.

  This module defines a struct and some helper functions for assigning values into it easily.

  ## Context fields

  * `module` - The module that is using the Pax Interface
  * `config` - The processed `Pax.Config` map.
  * `adapter` - The adapter module to use for the interface
  * `plugins` - A list of plugins to use for the interface
  * `action` - The current action being performed, one of `:index`, `:show`, `:edit`, `:new` or `:delete`
  * `objects` - A list of objects to display, for the `:index` action
  * `object` - The current object being displayed in `:show`, `:edit` or `:delete` actions
  * `object_count` - The number of objects in the `:objects` list
  * `path` - The path of the URL of the current page, as a `%URI{}` with only `path` and `query` fields set.
  * `form` - The form to use for the current object in `:new` or `:edit` actions
  * `singular_name` - The singular name of the object
  * `plural_name` - The plural name of the object
  * `object_name` - The name of the object being displayed
  * `index_path` - The path to the index page
  * `index_query` - An encoded query for the Index page, if any. Used by Detail Interface views for index links.
  * `new_path` - The path to the new page
  * `show_path` - The path to the show page
  * `edit_path` - The path to the edit page
  * `fields` - A list of fields to display in the index page
  * `scope` - A map of scope values to use for the adapter, see the [Scope](#scope) section
  * `private` - A map of private values for pax internals and plugins to use, see the [Private](#private) section

  ## Scope

  The `:scope` map is used to pass information to the adapter for it to do some of its basic operations, such as
  fetching objects for the index pages, or fetching individual objects for the show, edit and delete pages. The main
  purpose of the scope is to decouple the interface, plugins and implementing module from the adapter, so that the
  adapter is not concerned with any of those things, it simply operates on a set of expected keys in the scope. In this
  way the adapter is only loosely coupled with the rest of the system.

  Any keys can be set in the scope, since it's a map, but adapter(s) will only be expecting certain keys to be set,
  and the interface and plugins will only set certain keys. All of these interactions should be documented in the
  respective modules.

  ## Private

  The `:private` map is used to store data for plugins to use. The private map is keyed by a `prefix`, which is
  typically the name of the plugin. This allows plugins to store their own data without interfering with
  each other. The private map is not intended to be used by the interface or the implementing module using Pax.

  """

  import Phoenix.Component, only: [assign: 3]
  alias Pax.Interface.Context

  defstruct module: nil,
            config: %{},
            adapter: nil,
            plugins: [],
            action: nil,
            objects: [],
            object: nil,
            object_count: 0,
            path: nil,
            form: nil,
            singular_name: nil,
            plural_name: nil,
            object_name: nil,
            index_path: nil,
            index_query: nil,
            new_path: nil,
            show_path: nil,
            edit_path: nil,
            id_fields: [],
            fields: [],
            default_scope: %{},
            scope: %{},
            private: %{}

  @doc """
  Assigns a value to the `:pax` context in the socket or assigns map.
  """

  def assign_pax(socket_or_assigns, key, value)

  def assign_pax(%Phoenix.LiveView.Socket{} = socket, key, value) do
    pax = Map.get(socket.assigns, :pax, %Context{})
    assign(socket, :pax, %{pax | key => value})
  end

  def assign_pax(%{} = assigns, key, value) do
    pax = Map.get(assigns, :pax, %Context{})
    assign(assigns, :pax, %{pax | key => value})
  end

  def assign_pax(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax(acc, key, value)
    end)
  end

  @doc """
  Makes sure that the given `prefix` exists in the `:private` map in the `:pax` context in the socket or assigns map.
  """
  def ensure_pax_private(socket_or_assigns, prefix)

  def ensure_pax_private(%Phoenix.LiveView.Socket{} = socket, prefix) do
    private =
      socket.assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:private, %{})

    assign_pax(socket, :private, Map.put_new(private, prefix, %{}))
  end

  def ensure_pax_private(%{} = assigns, prefix) do
    private =
      assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:private, %{})

    assign_pax(assigns, :private, Map.put_new(private, prefix, %{}))
  end

  @doc """
  Assigns the `value` to the `:private` map under the `prefix` in the `:pax` context in the assigns.
  """
  def assign_pax_private(socket_or_assigns, prefix, key, value)

  def assign_pax_private(%Phoenix.LiveView.Socket{} = socket, prefix, key, value) do
    private =
      socket.assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:private, %{})

    prefixed =
      private
      |> Map.get(prefix, %{})
      |> Map.put(key, value)

    assign_pax(socket, :private, Map.put(private, prefix, prefixed))
  end

  def assign_pax_private(%{} = assigns, prefix, key, value) do
    private =
      assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:private, %{})

    prefixed =
      private
      |> Map.get(prefix, %{})
      |> Map.put(key, value)

    assign_pax(assigns, :private, Map.put(private, prefix, prefixed))
  end

  def assign_pax_private(socket_or_assigns, prefix, keyword_or_map)
      when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax_private(acc, prefix, key, value)
    end)
  end

  @doc """
  Assigns a value to the `:scope` map in the `:pax` context in the socket or assigns map.
  """

  def assign_pax_scope(socket_or_assigns, key, value)

  def assign_pax_scope(%Phoenix.LiveView.Socket{} = socket, key, value) do
    scope =
      socket.assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:scope, %{})

    assign_pax(socket, :scope, Map.put(scope, key, value))
  end

  def assign_pax_scope(%{} = assigns, key, value) do
    scope =
      assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:scope, %{})

    assign_pax(assigns, :scope, Map.put(scope, key, value))
  end

  def assign_pax_scope(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax_scope(acc, key, value)
    end)
  end
end
