defmodule SandboxWeb.Admin.AlbumResource do
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Album}
  end

  def config(_socket) do
    [
      id_fields: [:uuid],
      fields: [
        {:name, link: true},
        :artist_id,
        {:rating, round: 2},
        {:length, :string, value: {__MODULE__, :length}, only: [:index, :show]},
        {:length_sec, label: "Length (seconds)", only: [:edit, :new]},
        {:id, only: :show},
        {:uuid, only: :show}
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
end
