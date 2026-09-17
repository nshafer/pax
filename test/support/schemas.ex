defmodule PaxTest.Book do
  use Ecto.Schema
  import Ecto.Changeset

  schema "books" do
    field :title, :string
    field :rank, :integer
    field :rating, :float
    field :in_print, :boolean
    field :published, :date
    field :read_at, :time
    field :uuid, Ecto.UUID

    timestamps()
  end

  def changeset(book, params) do
    book
    |> cast(params, [:title, :rank, :rating, :in_print, :published])
    |> validate_required([:title])
  end
end

defmodule PaxTest.Membership do
  use Ecto.Schema

  @primary_key false
  schema "memberships" do
    field :org_id, :integer, primary_key: true
    field :user_id, :integer, primary_key: true
    field :role, :string
  end
end

defmodule PaxTest.NoKey do
  use Ecto.Schema

  @primary_key false
  schema "no_keys" do
    field :name, :string
  end
end

defmodule PaxTest.CustomType do
  use Ecto.Type
  def type, do: :string
  def cast(value), do: {:ok, value}
  def load(value), do: {:ok, value}
  def dump(value), do: {:ok, value}
end

defmodule PaxTest.AllTypes do
  use Ecto.Schema

  @primary_key {:uuid, :binary_id, autogenerate: true}
  schema "all_types" do
    field :ref_id, :id
    field :integer, :integer
    field :float, :float
    field :boolean, :boolean
    field :string, :string
    field :binary, :binary
    field :array, {:array, :string}
    field :map, :map
    field :typed_map, {:map, :string}
    field :decimal, :decimal
    field :date, :date
    field :time, :time
    field :time_usec, :time_usec
    field :naive_datetime, :naive_datetime
    field :naive_datetime_usec, :naive_datetime_usec
    field :utc_datetime, :utc_datetime
    field :utc_datetime_usec, :utc_datetime_usec
    field :ecto_uuid, Ecto.UUID
    field :enum, Ecto.Enum, values: [:one, :two]
    field :custom, PaxTest.CustomType
  end
end

defmodule PaxTest.Author do
  @moduledoc "An embedded schema used by LiveViews and resources that implement the data callbacks themselves."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  embedded_schema do
    field :name, :string
    field :born, :integer
    field :active, :boolean, default: true
  end

  def changeset(author, params) do
    author
    |> cast(params, [:name, :born, :active])
    |> validate_required([:name])
  end
end
