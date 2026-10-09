defmodule SandboxWeb.Admin.AshAlbumResource do
  @moduledoc """
  The same albums as `SandboxWeb.Admin.AlbumResource`, through `Pax.Adapters.Ash` instead.

  `Sandbox.Catalog.Album` is forbid-by-default, so the `actor` here is what makes the page work at all. It is
  resolved on every call, not captured at mount.
  """
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.Ash, resource: Sandbox.Catalog.Album}
  end

  def config(_socket) do
    [
      adapter: [actor: & &1.assigns.current_user],
      object_name: fn object, _socket -> object.name end,
      fields: [
        {:name, :string, link: true, sort: true},
        {:artist_id, :integer},
        {:label_id, :integer, except: :index},
        {:rating, :float, round: 2, required: false, sort: true},
        {:length_sec, :integer, label: "Length (seconds)", sort: true},
        {:id, :integer, only: :show, immutable: true},
        {:uuid, :string, only: :show, immutable: true}
      ],
      default_criteria: [order_by: :name]
    ]
  end
end
