defmodule SandboxWeb.Admin.LabelResource do
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Label}
  end

  def plugins(_socket) do
    [
      Pax.Plugins.Title,
      {Pax.Plugins.Pagination, objects_per_page: 100},
      Pax.Plugins.IndexTable,
      Pax.Plugins.DetailFieldsets,
      Pax.Plugins.ActionButtons
    ]
  end

  def config(_socket) do
    [
      fields: [
        {:id, sort: true},
        {:name, link: true, sort: true},
        :founded,
        {:rating, :float, round: 2},
        :accepting_submissions,
        {:inserted_at, immutable: true, except: :index},
        {:updated_at, immutable: true, except: :index}
      ],
      default_scope: [
        order_by: [:name, desc: :founded]
      ],
      plugins: [
        detail_fieldsets: [
          fieldsets: [
            default: [
              [:name, :slug],
              :rating,
              :accepting_submissions
            ],
            meta: [
              :id,
              [:inserted_at, :updated_at]
            ]
          ]
        ]
      ]
    ]
  end
end
