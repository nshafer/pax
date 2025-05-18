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
      Pax.Plugins.Pagination,
      Pax.Plugins.IndexTable,
      Pax.Plugins.DetailFieldsets
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
      fields: [
        {:id, immutable: true},
        {:slug, except: :index},
        {:name, link: true},
        {:rating_formatted, :string, label: "Rating", value: &format_rating/1, except: :edit},
        {:rating, :float, round: 2, only: :edit},
        {:started, :date, except: :index},
        {:ended, :date, except: :index},
        :current_label_id,
        {:inserted_at, :datetime, immutable: true, except: :index},
        {:updated_at, :datetime, immutable: true, except: :index}
      ],
      plugins: [
        detail_fieldsets: [
          fieldsets: [
            default: [
              [:name, :slug],
              :rating,
              :rating_formatted,
              :started,
              :ended
            ],
            metadata: [
              :id,
              :inserted_at,
              :updated_at
            ]
          ]
        ]
      ]
    ]
  end

  def format_rating(%{rating: nil}), do: "-"
  def format_rating(%{rating: rating}), do: rating |> Float.round(2) |> Float.to_string()
end
