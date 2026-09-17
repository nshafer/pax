defmodule Pax.FieldTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  alias Pax.Field
  alias PaxTest.Book

  defmodule ImmutableType do
    @behaviour Pax.Field.Type
    def init(opts), do: %{locked: Keyword.get(opts, :locked, true)}
    def render(_opts, value), do: value
    def input(_opts, _field, _form_field), do: "input"
    def immutable?(opts), do: opts.locked
  end

  defmodule NotAType do
  end

  def link_for(book), do: "/books/#{book.id}"
  def value_with_name(name, book), do: "#{name}: #{book.title}"
  def value_for(book), do: String.upcase(book.title)

  defp adapter do
    Pax.Adapter.init(Pax.Adapters.EctoSchema, __MODULE__, repo: PaxTest.Repo, schema: Book)
  end

  defp book, do: %Book{id: 1, title: "Dune", rank: 3}

  describe "init/2" do
    test "introspects the type from the adapter" do
      assert %Field{name: :title, type: Field.String} = Field.init(adapter(), :title)

      assert %Field{name: :rank, type: Field.Integer, opts: %{label: "Place"}} =
               Field.init(adapter(), {:rank, label: "Place"})
    end

    test "raises when the type can't be introspected without an adapter" do
      assert_raise RuntimeError, ~r/Unable to introspect field :title/, fn -> Field.init(nil, :title) end
      assert_raise RuntimeError, ~r/Unable to introspect field :title/, fn -> Field.init(nil, {:title, label: "T"}) end
    end

    test "raises when the adapter doesn't know the field" do
      assert_raise RuntimeError, ~r/Unknown field :nope/, fn -> Field.init(adapter(), :nope) end
    end

    test "maps built-in type names to their modules" do
      assert Field.init(nil, {:a, :boolean}).type == Field.Boolean
      assert Field.init(nil, {:a, :date}).type == Field.Date
      assert Field.init(nil, {:a, :datetime}).type == Field.Datetime
      assert Field.init(nil, {:a, :time}).type == Field.Time
      assert Field.init(nil, {:a, :float}).type == Field.Float
      assert Field.init(nil, {:a, :integer}).type == Field.Integer
      assert Field.init(nil, {:a, :string}).type == Field.String
    end

    test "accepts custom type modules" do
      assert %Field{type: ImmutableType, opts: %{locked: false}} = Field.init(nil, {:a, ImmutableType, locked: false})
      assert %Field{type: ImmutableType, opts: %{locked: true}} = Field.init(nil, {:a, ImmutableType})
    end

    test "merges the global opts over the type's opts, dropping unknown opts" do
      field = Field.init(nil, {:title, :string, truncate: 10, label: "Title", required: false, unknown: true})

      assert field.opts == %{truncate: 10, label: "Title", required: false}
    end

    test "raises on invalid fieldspecs" do
      assert_raise ArgumentError, ~r/Invalid fieldspec "title"/, fn -> Field.init(nil, "title") end

      assert_raise ArgumentError, ~r/Invalid fieldspec {"title", :string}/, fn ->
        Field.init(nil, {"title", :string})
      end

      assert_raise ArgumentError, ~r/Invalid fieldspec/, fn -> Field.init(nil, {:title, :string, :opts}) end
    end

    test "raises on invalid types" do
      assert_raise ArgumentError, "Invalid field type: :decimal.", fn -> Field.init(nil, {:a, :decimal}) end

      assert_raise ArgumentError, "Invalid field type: Pax.FieldTest.NotAType.", fn ->
        Field.init(nil, {:a, NotAType})
      end
    end

    test "raises on field names starting with reserved characters" do
      assert_raise ArgumentError, ~r/cannot start with a period/, fn -> Field.init(nil, {:".a", :string}) end
      assert_raise ArgumentError, ~r/cannot start with a hyphen/, fn -> Field.init(nil, {:"-a", :string}) end
      assert_raise ArgumentError, ~r/cannot start with an underscore/, fn -> Field.init(nil, {:_a, :string}) end
      assert_raise ArgumentError, ~r/cannot start with a tilde/, fn -> Field.init(nil, {:"~a", :string}) end
    end

    test "accepts valid link opts" do
      for link <- [true, {__MODULE__, :link_for}, &link_for/1, "/books", URI.parse("/books")] do
        assert Field.init(nil, {:title, :string, link: link}).opts.link == link
      end
    end

    test "raises on invalid link opts" do
      assert_raise RuntimeError, "Invalid link option for field title: 123", fn ->
        Field.init(nil, {:title, :string, link: 123})
      end
    end

    test "resolves the sort opt to the field to sort by" do
      assert Field.init(nil, {:title, :string, sort: true}).opts.sort == :title
      assert Field.init(nil, {:title, :string, sort: :sort_title}).opts.sort == :sort_title
      refute Map.has_key?(Field.init(nil, {:title, :string, sort: false}).opts, :sort)
      refute Map.has_key?(Field.init(nil, {:title, :string}).opts, :sort)

      assert_raise ArgumentError, ~r/Invalid sort option for field title: "title"/, fn ->
        Field.init(nil, {:title, :string, sort: "title"})
      end
    end

    test "validates the sort_asc and sort_desc opts" do
      for dir <- [:asc, :asc_nulls_first, :asc_nulls_last] do
        assert Field.init(nil, {:title, :string, sort_asc: dir}).opts.sort_asc == dir
      end

      for dir <- [:desc, :desc_nulls_first, :desc_nulls_last] do
        assert Field.init(nil, {:title, :string, sort_desc: dir}).opts.sort_desc == dir
      end

      assert_raise ArgumentError, ~r/Invalid sort_asc option for field title: :desc/, fn ->
        Field.init(nil, {:title, :string, sort_asc: :desc})
      end

      assert_raise ArgumentError, ~r/Invalid sort_desc option for field title: :asc/, fn ->
        Field.init(nil, {:title, :string, sort_desc: :asc})
      end
    end
  end

  describe "label/1" do
    test "uses the label opt, or introspects one from the name" do
      assert Field.label(Field.init(nil, {:first_name, :string})) == "First Name"
      assert Field.label(Field.init(nil, {:first_name, :string, label: "Given name"})) == "Given name"
    end
  end

  describe "link/3" do
    test "returns nil when there is no link" do
      assert Field.link(Field.init(nil, {:title, :string}), book()) == nil
      assert Field.link(Field.init(nil, {:title, :string}), book(), params: [a: 1], local_params: [b: 2]) == nil
    end

    test "returns static links as given" do
      assert Field.link(Field.init(nil, {:title, :string, link: "/books"}), book()) == "/books"
      assert Field.link(Field.init(nil, {:title, :string, link: URI.parse("/books")}), book()) == URI.parse("/books")
    end

    test "calls link functions with the object" do
      assert Field.link(Field.init(nil, {:title, :string, link: {__MODULE__, :link_for}}), book()) == "/books/1"
      assert Field.link(Field.init(nil, {:title, :string, link: &link_for/1}), book()) == "/books/1"
    end

    test "normalizes the values returned from link functions" do
      for {returned, expected} <- [{nil, nil}, {false, nil}, {:"/atom", "/atom"}, {"/str", "/str"}] do
        field = Field.init(nil, {:title, :string, link: fn _ -> returned end})
        assert Field.link(field, book()) == expected
      end

      uri = URI.parse("/uri")
      assert Field.link(Field.init(nil, {:title, :string, link: fn _ -> uri end}), book()) == uri

      assert_raise RuntimeError, ~r/Invalid link returned from link\/1 function for field :title/, fn ->
        Field.link(Field.init(nil, {:title, :string, link: fn _ -> 123 end}), book())
      end
    end

    test "raises when the link function is not a fn/1 or exported" do
      assert_raise ArgumentError, ~r/Invalid function arity.*Must be a fn\/1/, fn ->
        Field.link(Field.init(nil, {:title, :string, link: fn _, _ -> "/" end}), book())
      end

      assert_raise UndefinedFunctionError, ~r/Pax.FieldTest.missing\/1 is undefined or private/, fn ->
        Field.link(Field.init(nil, {:title, :string, link: {__MODULE__, :missing}}), book())
      end
    end

    test "adds params to every link" do
      field = Field.init(nil, {:title, :string, link: &link_for/1})
      assert Field.link(field, book(), params: [page: 2]) == "/books/1?page=2"

      field = Field.init(nil, {:title, :string, link: URI.parse("https://example.com/books")})
      assert Field.link(field, book(), params: [page: 2]) == "https://example.com/books?page=2"
    end

    test "adds local_params only to links without a host" do
      field = Field.init(nil, {:title, :string, link: "/books"})
      assert Field.link(field, book(), local_params: [page: 2]) == "/books?page=2"

      field = Field.init(nil, {:title, :string, link: "https://example.com/books"})
      assert URI.to_string(Field.link(field, book(), local_params: [page: 2])) == "https://example.com/books"
    end
  end

  describe "set_link/2" do
    test "replaces the link opt" do
      field = Field.init(nil, {:title, :string}) |> Field.set_link("/new")
      assert field.opts.link == "/new"
    end
  end

  describe "render/2" do
    test "renders the object's value for the field" do
      assert Field.render(Field.init(nil, {:title, :string}), book()) == "Dune"
      assert Field.render(Field.init(nil, {:rank, :integer}), book()) == "3"
    end

    test "renders nil values as a bullet" do
      assert Field.render(Field.init(nil, {:rating, :float}), book()) == "•"
    end

    test "resolves the value opt" do
      assert Field.render(Field.init(nil, {:x, :string, value: :title}), book()) == "Dune"
      assert Field.render(Field.init(nil, {:x, :string, value: {__MODULE__, :value_with_name}}), book()) == "x: Dune"
      assert Field.render(Field.init(nil, {:x, :string, value: {__MODULE__, :value_for}}), book()) == "DUNE"
      assert Field.render(Field.init(nil, {:x, :string, value: &value_for/1}), book()) == "DUNE"
      assert Field.render(Field.init(nil, {:x, :string, value: &value_with_name/2}), book()) == "x: Dune"
      assert Field.render(Field.init(nil, {:x, :string, value: "static"}), book()) == "static"
    end

    test "raises on invalid value opts" do
      assert_raise RuntimeError, "Invalid value: :nope. Must be a field name.", fn ->
        Field.render(Field.init(nil, {:x, :string, value: :nope}), %{title: "Dune"})
      end

      assert_raise UndefinedFunctionError, ~r/functions Elixir.Pax.FieldTest.missing\/1 or/, fn ->
        Field.render(Field.init(nil, {:x, :string, value: {__MODULE__, :missing}}), book())
      end

      assert_raise ArgumentError, ~r/Invalid function arity.*Must be a fn\/1 or fn\/2/, fn ->
        Field.render(Field.init(nil, {:x, :string, value: fn -> "x" end}), book())
      end
    end
  end

  describe "immutable?/1" do
    test "is false by default" do
      refute Field.immutable?(Field.init(nil, {:title, :string}))
    end

    test "is true with the immutable opt, or a value opt" do
      assert Field.immutable?(Field.init(nil, {:title, :string, immutable: true}))
      refute Field.immutable?(Field.init(nil, {:title, :string, immutable: false}))
      assert Field.immutable?(Field.init(nil, {:title, :string, value: :rank}))
    end

    test "asks the type when it implements immutable?/1" do
      assert Field.immutable?(Field.init(nil, {:title, ImmutableType}))
      refute Field.immutable?(Field.init(nil, {:title, ImmutableType, locked: false}))
    end
  end

  describe "required?/1" do
    test "is true unless required: false" do
      assert Field.required?(Field.init(nil, {:title, :string}))
      assert Field.required?(Field.init(nil, {:title, :string, required: true}))
      refute Field.required?(Field.init(nil, {:title, :string, required: false}))
    end
  end

  describe "mutable_fields/1 and validate_required/2" do
    test "only mutable, required fields are validated" do
      fields = [
        Field.init(nil, {:title, :string}),
        Field.init(nil, {:rank, :integer, required: false}),
        Field.init(nil, {:rating, :float, immutable: true})
      ]

      assert Enum.map(Field.mutable_fields(fields), & &1.name) == [:title, :rank]

      changeset = Ecto.Changeset.cast(%Book{}, %{}, [:title, :rank, :rating]) |> Field.validate_required(fields)
      assert Keyword.keys(changeset.errors) == [:title]
    end
  end

  describe "label_for/2" do
    test "uses the field name without a form" do
      assert Field.label_for(Field.init(nil, {:title, :string}), nil) == :title
    end

    test "uses the form field's id" do
      form = to_form(Ecto.Changeset.change(%Book{}), as: :detail)
      assert Field.label_for(Field.init(nil, {:title, :string}), form) == "detail_title"
    end

    test "uses the field name when the form has no such field" do
      assert Field.label_for(Field.init(nil, {:title, :string}), %{}) == :title
    end
  end

  describe "input/2" do
    test "renders the type's input for the form field" do
      form = to_form(Ecto.Changeset.change(%Book{title: "Dune"}), as: :detail)
      html = PaxTest.HTML.to_html(Field.input(Field.init(nil, {:title, :string}), form))

      assert html =~ ~s(name="detail[title]")
      assert html =~ ~s(value="Dune")
    end
  end

  describe "errors/2" do
    test "returns no errors for inputs that haven't been used" do
      changeset = Book.changeset(%Book{}, %{}) |> Map.put(:action, :validate)
      form = to_form(changeset, as: :detail)

      assert Field.errors(Field.init(nil, {:title, :string}), form) == []
    end

    test "returns translated errors for used inputs" do
      changeset =
        %Book{}
        |> Book.changeset(%{"title" => ""})
        |> Ecto.Changeset.validate_length(:title, min: 3)
        |> Map.put(:action, :validate)

      form = to_form(changeset, as: :detail)

      assert Field.errors(Field.init(nil, {:title, :string}), form) == ["can't be blank"]
    end
  end

  describe "translate_error/1" do
    test "interpolates the opts" do
      assert Field.translate_error({"is invalid", []}) == "is invalid"
      assert Field.translate_error({"must be %{thing}", thing: "big"}) == "must be big"
    end

    test "uses the count for plural messages" do
      msg = "should be at least %{count} character(s)"
      assert Field.translate_error({msg, count: 3, validation: :length}) == "should be at least 3 character(s)"
    end
  end
end
