defmodule SandboxWeb.Admin.LabelResource do
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Label}
  end

  def config(_socket) do
    [
      index_fields: [
        :id,
        {:name, link: true},
        :rating,
        :accepting_submissions,
        :inserted_at,
        :updated_at
      ],
      fieldsets: [
        default: [
          [
            {:name, :string},
            {:slug, :string}
          ],
          [{:rating, :float, label: "Rating (0-5)", round: 2}, :founded],
          {:accepting_submissions, :boolean, true: "Yes", false: "No"}
        ],
        meta: [
          {:id, :integer, label: "ID#", immutable: true},
          {:inserted_at, :datetime, immutable: true},
          {:updated_at, :datetime, immutable: true}
        ]
      ]
    ]
  end
end
