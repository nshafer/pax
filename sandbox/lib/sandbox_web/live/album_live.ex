defmodule SandboxWeb.AlbumLive do
  use SandboxWeb, :live_view
  use Pax.Interface
  alias Sandbox.Library

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <Pax.Interface.Components.pax_interface :if={assigns[:pax]} pax={@pax} />
    </Layouts.app>
    """
  end

  # @impl true
  # def pax_adapter(_socket) do
  #   {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Album}
  # end

  def count_objects(_criteria, _socket) do
    Library.count_albums()
  end

  def list_objects(criteria, _socket) do
    Library.list_albums(criteria)
  end

  def new_object(_socket) do
    Library.new_album()
  end

  def get_object(lookup, criteria, _socket) do
    Library.get_album!(lookup, criteria)
  end

  def change_object(object, params, _socket) do
    Library.change_album(object, params)
  end

  def create_object(_object, changeset, _socket) do
    Library.create_album(changeset.params)
  end

  def update_object(object, changeset, _socket) do
    Library.update_album(object, changeset.params)
  end

  def pax_plugins(_socket) do
    [
      Pax.Plugins.Breadcrumbs,
      Pax.Plugins.Title,
      Pax.Plugins.Pagination,
      Pax.Plugins.IndexTable,
      Pax.Plugins.DetailFieldsets,
      Pax.Plugins.ActionButtons
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
      singular_name: "Album",
      plural_name: "Albums",
      object_name: fn object, _socket -> object.name end,
      fields: [
        {:id, :integer, immutable: true, only: :show},
        {:uuid, :string, immutable: true, only: :show},
        {:name, :string, link: true, sort: true},
        {:artist_id, :integer},
        {:rating, :float, round: 3, sort: true, sort_asc: :asc_nulls_first, sort_desc: :desc_nulls_last},
        {:length_sec, :integer, sort: true},
        {:label_id, :integer, except: :index},
        {:inserted_at, :datetime, immutable: true, except: :index},
        {:updated_at, :datetime, immutable: true, except: :index}
      ],
      default_criteria: [
        order_by: :name,
        where: [
          # artist_id: 6
        ]
      ]
    ]
  end
end
