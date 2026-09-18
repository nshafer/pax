defmodule Pax.Admin.Config do
  @moduledoc """
  Configuration for a Pax.Admin.

  Set it with the `Pax.Admin.config/1` macro in your admin module, or return it from the optional
  `c:Pax.Admin.config/3` callback. It is validated with `Pax.Config` when every page in the admin mounts, the dashboard
  and every resource page.

  ## Configuration

  The following configuration keys are supported:

  ### `title`

  The title shown at the top of every admin page. If not given, "Pax Admin" is shown.

  Valid values:
  * `string` - A string value.
  * `function` - A function that takes the socket and returns a string.

  ## Examples

      config title: "My Admin"

      config title: fn socket -> "Admin for \#{socket.assigns.current_user.name}" end

      def config(_params, _session, socket) do
        [title: "Admin for \#{socket.assigns.current_user.name}"]
      end
  """

  def config_spec() do
    %{
      title: [:string, {:function, 1, :string}]
    }
  end
end
