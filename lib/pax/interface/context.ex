defmodule Pax.Interface.Context do
  import Phoenix.Component, only: [assign: 3]
  alias Pax.Interface.Context

  defstruct [
    :module,
    :adapter,
    :plugins,
    :singular_name,
    :plural_name,
    :object_name,
    :index_path,
    :new_path,
    :show_path,
    :edit_path,
    :fields,
    :fieldsets
  ]

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
end
