defmodule Pax.Admin.Context do
  import Phoenix.Component, only: [assign: 3]
  alias Pax.Admin.Context

  defstruct [:site_mod, :config, :resources, :resource]

  def assign_admin(socket_or_assigns, key, value)

  def assign_admin(%Phoenix.LiveView.Socket{} = socket, key, value) do
    pax =
      socket.assigns
      |> Map.get(:pax_admin, %Context{})
      |> Map.put(key, value)

    assign(socket, :pax_admin, pax)
  end

  def assign_admin(%{} = assigns, key, value) do
    pax =
      assigns
      |> Map.get(:pax, %Context{})
      |> Map.put(key, value)

    assign(assigns, :pax_admin, pax)
  end

  def assign_admin(socket_or_assigns, keyword_or_map) when is_map(keyword_or_map) or is_list(keyword_or_map) do
    Enum.reduce(keyword_or_map, socket_or_assigns, fn {key, value}, acc ->
      assign_admin(acc, key, value)
    end)
  end
end
