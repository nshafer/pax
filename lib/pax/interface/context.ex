defmodule Pax.Interface.Context do
  import Phoenix.Component, only: [assign: 3]
  alias Pax.Interface.Context

  defstruct module: nil,
            adapter: nil,
            plugins: [],
            objects: [],
            object_count: 0,
            url: nil,
            form: nil,
            singular_name: nil,
            plural_name: nil,
            object_name: nil,
            index_path: nil,
            new_path: nil,
            show_path: nil,
            edit_path: nil,
            fields: [],
            fieldsets: [],
            scope: %{},
            private: %{}

  @doc """
  Assigns a value to the `:pax` context in the socket or assigns map.
  """

  def assign_pax(socket_or_assigns, key, value)

  def assign_pax(%Phoenix.LiveView.Socket{} = socket, key, value) do
    pax =
      socket.assigns
      |> Map.get(:pax, %Context{})
      |> Map.put(key, value)

    assign(socket, :pax, pax)
  end

  def assign_pax(%{} = assigns, key, value) do
    pax =
      assigns
      |> Map.get(:pax, %Context{})
      |> Map.put(key, value)

    assign(assigns, :pax, pax)
  end

  def assign_pax(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax(acc, key, value)
    end)
  end

  @doc """
  Assigns a value a map in the `:private` map in the `:pax` context in the socket or assigns map.
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
      |> Map.put(key, value)

    assign_pax(socket, :scope, scope)
  end

  def assign_pax_scope(%{} = assigns, key, value) do
    scope =
      assigns
      |> Map.get(:pax, %Context{})
      |> Map.get(:scope, %{})
      |> Map.put(key, value)

    assign_pax(assigns, :scope, scope)
  end

  def assign_pax_scope(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_pax_scope(acc, key, value)
    end)
  end
end
