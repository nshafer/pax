defmodule SandboxWeb.PageController do
  use SandboxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
