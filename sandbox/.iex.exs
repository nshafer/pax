# Default imports and aliases
import Ecto.Query, only: [from: 1, from: 2]

alias SandboxWeb.Endpoint
alias Sandbox.Repo

alias Sandbox.Library
alias Sandbox.Library.{Label, Artist, Album}

# iex configuration
IEx.configure(
  inspect: [
    custom_options: [sort_maps: true]
  ]
)
