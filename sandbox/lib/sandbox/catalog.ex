defmodule Sandbox.Catalog do
  @moduledoc """
  An Ash domain over the same tables as `Sandbox.Library`, so the two adapters can be compared side by side.

  `Sandbox.Library` is the Ecto context and owns the schema: these resources set `migrate? false`, so
  `mix ash.codegen` has nothing to generate and the existing migrations and seeds stay the single source of
  truth. The admin registers resources from both, over the same rows.
  """
  use Ash.Domain

  resources do
    resource(Sandbox.Catalog.Label)
    resource(Sandbox.Catalog.Artist)
    resource(Sandbox.Catalog.Album)
  end
end
