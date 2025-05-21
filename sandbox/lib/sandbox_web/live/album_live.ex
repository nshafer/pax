defmodule SandboxWeb.AlbumLive do
  use SandboxWeb, :live_view
  use Pax.Interface

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      {Pax.Interface.Components.pax_interface(assigns)}
    </Layouts.app>
    """
  end

  def pax_adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Album}
  end

  def pax_plugins(_socket) do
    [
      Pax.Plugins.Breadcrumbs,
      Pax.Plugins.Title,
      Pax.Plugins.Pagination,
      Pax.Plugins.IndexTable,
      Pax.Plugins.DetailFieldsets
    ]
  end

  def pax_config(_socket) do
    [
      id_fields: [:uuid],
      lookup_params: ["uuid"],
      index_path: ~p"/albums",
      new_path: ~p"/albums/new",
      show_path: fn object, _socket -> ~p"/albums/#{object.uuid}" end,
      edit_path: fn object, _socket -> ~p"/albums/#{object.uuid}/edit" end,
      object_name: fn object, _socket -> object.name end,
      fields: [
        {:id, immutable: true, only: :show},
        {:uuid, immutable: true, only: :show},
        {:name, link: true},
        :artist_id,
        {:rating, :float, round: 3},
        :length_sec,
        {:label_id, except: :index},
        {:inserted_at, :datetime, immutable: true, except: :index},
        {:updated_at, :datetime, immutable: true, except: :index}
      ],
      default_scope: [
        order_by: :name
      ]
    ]
  end
end
