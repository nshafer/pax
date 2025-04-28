defmodule SandboxWeb.ArtistLive do
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
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Artist}
  end

  def pax_plugins(_socket) do
    [
      Pax.Plugins.Breadcrumbs,
      Pax.Plugins.Title,
      Pax.Plugins.Pagination
    ]
  end

  def pax_config(_socket) do
    [
      id_fields: [:slug],
      lookup_params: ["slug"],
      index_path: ~p"/artists",
      new_path: ~p"/artists/new",
      show_path: fn object, _socket -> ~p"/artists/#{object.slug}" end,
      edit_path: fn object, _socket -> ~p"/artists/#{object.slug}/edit" end,
      object_name: fn object, _socket -> object.name end,
      index_fields: [
        :id,
        {:name, link: true},
        {:rating, :string, value: &format_rating/1},
        :current_label_id
        # :inserted_at,
        # {:updated_at, :datetime, format: "%Y-%m-%d %H:%M:%S"}
      ],
      fieldsets: [
        default: [
          [:name, :slug],
          {:rating, :float, round: 2},
          :started,
          :ended
        ],
        metadata: [
          [
            {:id, immutable: true},
            {:inserted_at, :datetime, immutable: true},
            {:updated_at, :datetime, immutable: true}
          ]
        ]
      ]
    ]
  end

  def format_rating(%{rating: nil}), do: "-"
  def format_rating(%{rating: rating}), do: rating |> Float.round(2) |> Float.to_string()
end
