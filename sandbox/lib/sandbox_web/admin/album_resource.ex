defmodule SandboxWeb.Admin.AlbumResource do
  use Pax.Admin.Resource
  alias Sandbox.Library

  # def adapter(_socket) do
  #   {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Album}
  # end

  def config(_socket) do
    [
      singular_name: "Album",
      plural_name: "Albums",
      id_fields: [:uuid],
      fields: [
        {:name, :string, link: true, sort: true},
        {:artist_id, :integer},
        {:label_id, :integer, except: :index},
        {:rating, :float, round: 2, sort: true},
        {:length, :string, value: {__MODULE__, :length}, only: [:index, :show], sort: :length_sec},
        {:length_sec, :integer, label: "Length (seconds)", only: [:edit, :new]},
        {:id, :integer, only: :show},
        {:uuid, :string, immutable: true, except: [:index, :edit, :new]}
      ],
      default_scope: [
        order_by: :name
      ]
    ]
  end

  def length(album) do
    if album.length_sec do
      min = div(album.length_sec, 60)
      sec = rem(album.length_sec, 60) |> to_string() |> String.pad_leading(2, "0")
      "#{min}:#{sec}"
    else
      "-"
    end
  end

  def object_name(object, _socket) do
    object.name
  end

  def count_objects(_scope, _socket) do
    Library.count_albums()
  end

  def list_objects(scope, _socket) do
    Library.list_albums(scope)
  end

  def new_object(_socket) do
    Library.new_album()
  end

  def get_object(lookup, scope, _socket) do
    Library.get_album!(lookup, scope)
  end

  def change_object(object, params, _socket) do
    Library.change_album(object, params)
  end

  def create_object(_object, _changeset, params, _socket) do
    Library.create_album(params)
  end

  def update_object(object, _changeset, params, _socket) do
    Library.update_album(object, params)
  end
end
