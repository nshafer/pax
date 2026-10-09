defmodule SandboxWeb.CurrentUser do
  @moduledoc """
  Assigns a hardcoded `current_user`, standing in for real authentication the sandbox does not have.

  `Sandbox.Catalog.Album` is forbid-by-default, and `Pax.Adapters.Ash` resolves its actor from this assign on
  every call. The point is that it is resolved per call: set `?actor=none` on any admin URL to drop it and see
  what a page does when the data layer refuses, which is what a host gets wrong if the actor is captured at
  mount instead.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  @admin %{id: 1, name: "Ursula", admin?: true}
  @guest %{id: 2, name: "Guest", admin?: false}

  def on_mount(:current_user, _params, _session, socket) do
    socket =
      socket
      |> assign(:current_user, @admin)
      |> attach_hook(:current_user, :handle_params, &put_current_user/3)

    {:cont, socket}
  end

  defp put_current_user(params, _uri, socket) do
    {:cont, assign(socket, :current_user, user_for(params))}
  end

  defp user_for(%{"actor" => "none"}), do: nil
  defp user_for(%{"actor" => "guest"}), do: @guest
  defp user_for(_params), do: @admin
end
