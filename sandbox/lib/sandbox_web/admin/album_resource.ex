defmodule SandboxWeb.Admin.AlbumResource do
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Album}
  end

  def config(_socket) do
    [
      id_fields: [:uuid],
      index_fields: [
        :id,
        # {:uuid, link: true},
        {:name, link: true},
        :artist_id,
        {:rating, round: 2},
        {:length, :string, value: {__MODULE__, :length}}
      ],
      fieldsets: [
        default: [
          [{:id, immutable: true}, {:uuid, immutable: true}],
          :name,
          :rating,
          :length_sec,
          :artist_id,
          {:length, :string, value: {__MODULE__, :length}}
        ]
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
end
