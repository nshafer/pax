defmodule PaxTest.Endpoint do
  use Phoenix.Endpoint, otp_app: :pax

  @session_options [
    store: :cookie,
    key: "_pax_test_key",
    signing_salt: "pax-test-session",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Pax.Assets

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]

  plug Plug.Session, @session_options
  plug PaxTest.Router
end

defmodule PaxTest.Router do
  use Phoenix.Router
  use Pax.Admin.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PaxTest.Layouts, :root}
    plug :protect_from_forgery
  end

  scope "/" do
    pipe_through :browser

    live_session :interface do
      live "/interface", PaxTest.InterfaceLive, :index
      live "/interface/new", PaxTest.InterfaceLive, :new
      live "/interface/glob/*ids", PaxTest.InterfaceLive, :show
      live "/interface/:id", PaxTest.InterfaceLive, :show
      live "/interface/:id/edit", PaxTest.InterfaceLive, :edit
      live "/interface/:id/delete", PaxTest.InterfaceLive, :delete
      live "/interface/:id/other", PaxTest.InterfaceLive, :other
    end

    pax_admin "/admin", PaxTest.Admin
    pax_admin "/runtime-admin", PaxTest.RuntimeAdmin

    scope "/nested" do
      pax_admin "/custom", PaxTest.CustomAdmin, as: :custom, on_mount: PaxTest.CustomAdmin.Hook
    end
  end
end

defmodule PaxTest.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Pax Test</title>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end

defmodule PaxTest.ConnCase do
  @moduledoc """
  Test case for tests that drive the test endpoint, with `PhoenixTest` imported.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PaxTest.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest, except: [put_endpoint: 2]
      import PhoenixTest
      import PaxTest.ConnCase

      alias PaxTest.Owner
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Configure `PaxTest.InterfaceLive` for the current test. Each value may be a literal, or a function taking the same
  args as the callback of the same name.
  """
  def interface(callbacks) do
    PaxTest.Owner.put_all(callbacks)
  end

  @doc "The current page of a PhoenixTest session, parsed for the `PaxTest.HTML` helpers."
  def html(session), do: PhoenixTest.Driver.render_html(session)

  @doc """
  Flush every message matching `pattern` from the mailbox, returning the last one. The disconnected and connected
  mounts both run `handle_params`, so most messages arrive twice per visit.
  """
  defmacro last_received(pattern) do
    quote do
      PaxTest.ConnCase.__flush__(fn
        unquote(pattern) = message -> {:match, message}
        _ -> :no_match
      end)
    end
  end

  def __flush__(matcher, last \\ nil) do
    receive do
      message ->
        case matcher.(message) do
          {:match, message} ->
            __flush__(matcher, message)

          :no_match ->
            result = __flush__(matcher, last)
            send(self(), message)
            result
        end
    after
      0 -> last
    end
  end
end

defmodule PaxTest.ErrorHTML do
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
