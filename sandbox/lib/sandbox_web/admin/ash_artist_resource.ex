defmodule SandboxWeb.Admin.AshArtistResource do
  @moduledoc """
  The same artists as `SandboxWeb.Admin.ArtistResource`, through `Pax.Adapters.Ash` instead.

  Deliberately the bare minimum, like its Ecto twin, so everything on the page comes from the adapter
  introspecting the Ash resource.
  """
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.Ash, resource: Sandbox.Catalog.Artist}
  end
end
