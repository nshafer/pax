defmodule Pax.Admin.Layouts do
  use Phoenix.Component

  import Pax.Admin.Components

  # Import convenience functions from controllers
  import Phoenix.Controller,
    only: [get_csrf_token: 0]

  # HTML escaping functionality
  # import Phoenix.HTML

  # Shortcut for generating JS commands
  # alias Phoenix.LiveView.JS

  embed_templates "layouts/*"
end
