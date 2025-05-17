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
      index_fields: [
        :id,
        {:name, link: true},
        :artist_id,
        :rating,
        :length_sec
        # :inserted_at,
        # {:updated_at, :datetime, format: "%Y-%m-%d %H:%M:%S"}
      ],
      fieldsets: [
        default: [
          [:name, :artist_id],
          [:rating, :length_sec],
          :label_id
        ],
        metadata: [
          [
            {:id, immutable: true},
            {:uuid, immutable: true},
            {:inserted_at, :datetime, immutable: true},
            {:updated_at, :datetime, immutable: true}
          ]
        ]
      ]
    ]
  end
end
