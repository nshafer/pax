defmodule Pax.Plugins.DetailListTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import PaxTest.HTML
  import PaxTest.PluginHelpers
  alias Pax.Plugins.DetailList
  alias PaxTest.Author

  @author %Author{id: 1, name: "Ursula", born: 1929, active: true}

  @fields [
    Pax.Field.init(nil, {:name, :string}),
    Pax.Field.init(nil, {:born, :integer}),
    Pax.Field.init(nil, {:id, :integer, immutable: true})
  ]

  @pax %Pax.Interface{action: :show, object: @author, fields: @fields}

  test "has a valid config spec" do
    assert {:ok, _} = Pax.Config.validate(DetailList.config_spec(), %{}, validate_config_spec: true)
  end

  describe "render/3" do
    test "renders every field as text in the show body" do
      html = render_plugin(plugin(DetailList), :show_body, @pax)

      assert texts(html, ".pax-detail-list-item-label") == ["Name", "Born", "Id"]
      assert texts(html, ".pax-detail-list-field-text") == ["Ursula", "1929", "1"]
      assert count(html, "input") == 0
    end

    test "renders inputs for mutable fields with a form" do
      pax = %{@pax | action: :edit, form: to_form(Ecto.Changeset.change(@author), as: :detail)}

      for section <- [:edit_body, :new_body] do
        html = render_plugin(plugin(DetailList), section, pax)

        assert attr(html, "label", "for") == ["detail_name", "detail_born", "detail_id"]
        assert attr(html, ".pax-detail-list-field-input input", "name") == ["detail[name]", "detail[born]"]
        assert texts(html, ".pax-detail-list-field-text") == ["1"]
      end
    end

    test "renders only the configured fields, in order" do
      html = render_plugin(plugin(DetailList, [], fields: [:born, :missing, :name]), :show_body, @pax)
      assert texts(html, ".pax-detail-list-item-label") == ["Born", "Name"]

      html = render_plugin(plugin(DetailList, [], fields: fn _ -> [:id] end), :show_body, @pax)
      assert texts(html, ".pax-detail-list-item-label") == ["Id"]
    end

    test "raises on invalid field names" do
      assert_raise RuntimeError, ~r/Invalid field:\n\n"name"\n\nField name must be an atom./, fn ->
        render_plugin(plugin(DetailList, [], fields: ["name"]), :show_body, @pax)
      end
    end

    test "can be placed in a list of sections" do
      plugin = plugin(DetailList, [], placement: [:show_footer_primary])

      assert count(render_plugin(plugin, :show_footer_primary, @pax), ".pax-detail-list-item") == 3
      assert render_plugin(plugin, :show_body, @pax) == ""
    end

    test "can be placed in one section" do
      plugin = plugin(DetailList, [], placement: :show_footer_primary)
      assert count(render_plugin(plugin, :show_footer_primary, @pax), ".pax-detail-list-item") == 3
    end

    @tag :known_bug
    test "renders nothing in other sections when placed in one section" do
      plugin = plugin(DetailList, [], placement: :show_footer_primary)
      assert render_plugin(plugin, :show_body, @pax) == ""
    end
  end
end

defmodule Pax.Plugins.DetailFieldsetsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import PaxTest.HTML
  import PaxTest.PluginHelpers
  alias Pax.Plugins.DetailFieldsets
  alias PaxTest.Author

  @author %Author{id: 1, name: "Ursula", born: 1929, active: true}

  @fields [
    Pax.Field.init(nil, {:name, :string}),
    Pax.Field.init(nil, {:born, :integer}),
    Pax.Field.init(nil, {:active, :boolean}),
    Pax.Field.init(nil, {:id, :integer, immutable: true})
  ]

  @pax %Pax.Interface{action: :show, object: @author, fields: @fields}

  defp fieldsets(html) do
    html
    |> parse()
    |> LazyHTML.query(".pax-detail-fieldsets-fieldset")
    |> Enum.map(fn fieldset ->
      heading = fieldset |> LazyHTML.query(".pax-title") |> LazyHTML.text() |> squish()

      groups =
        fieldset
        |> LazyHTML.query(".pax-detail-fieldsets-fieldgroup")
        |> Enum.map(fn group -> group |> LazyHTML.query("label") |> Enum.map(&squish(LazyHTML.text(&1))) end)

      {heading, groups}
    end)
  end

  test "has a valid config spec" do
    assert {:ok, _} = Pax.Config.validate(DetailFieldsets.config_spec(), %{}, validate_config_spec: true)
  end

  describe "render/3" do
    test "renders every field in its own group in a default fieldset without a heading" do
      html = render_plugin(plugin(DetailFieldsets), :show_body, @pax)

      assert fieldsets(html) == [{"", [["Name"], ["Born"], ["Active"], ["Id"]]}]
      assert texts(html, ".pax-detail-fieldsets-field-text") == ["Ursula", "1929", "True", "1"]
      assert classes(html, ".pax-detail-fieldsets-fieldgroup") |> hd() =~ "pax-detail-fieldsets-fieldgroup-count-1"
    end

    test "renders the configured fieldsets and groups" do
      config = [
        fieldsets: [
          default: [[:name, :born], :missing],
          more_details: [[:active, :missing], :id],
          "Custom Heading": [:name]
        ]
      ]

      html = render_plugin(plugin(DetailFieldsets, [], config), :show_body, @pax)

      assert fieldsets(html) == [
               {"", [["Name", "Born"]]},
               {"More details", [["Active"], ["Id"]]},
               {"Custom heading", [["Name"]]}
             ]

      assert "pax-detail-fieldsets-fieldgroup pax-detail-fieldsets-fieldgroup-count-2" in classes(
               html,
               ".pax-detail-fieldsets-fieldgroup"
             )

      assert classes(html, ".pax-detail-fieldsets-field") |> Enum.take(2) == [
               "pax-detail-fieldsets-field pax-detail-fieldsets-field-0",
               "pax-detail-fieldsets-field pax-detail-fieldsets-field-1"
             ]
    end

    test "accepts string names and truncates long headings" do
      long = String.duplicate("a", 60)
      config = [fieldsets: fn _socket -> [{"Named", [:name]}, {String.to_atom(long), [:born]}] end]

      html = render_plugin(plugin(DetailFieldsets, [], config), :show_body, @pax)
      assert texts(html, ".pax-title") == ["Named", String.capitalize(String.duplicate("a", 49)) <> "…"]
    end

    test "renders inputs for mutable fields with a form" do
      pax = %{@pax | action: :edit, form: to_form(Ecto.Changeset.change(@author), as: :detail)}
      html = render_plugin(plugin(DetailFieldsets), :edit_body, pax)

      assert attr(html, ".pax-detail-fieldsets-field-input input[type=text]", "name") == [
               "detail[name]",
               "detail[born]"
             ]

      assert attr(html, "input[type=checkbox]", "name") == ["detail[active]"]
      assert texts(html, ".pax-detail-fieldsets-field-text") == ["1"]
    end

    test "raises on invalid fieldsets" do
      assert_raise RuntimeError, ~r/Invalid fieldset:\n\n:name/, fn ->
        render_plugin(plugin(DetailFieldsets, [], fieldsets: [:name]), :show_body, @pax)
      end

      assert_raise RuntimeError, ~r/Invalid fieldgroup:\n\n"name"/, fn ->
        render_plugin(plugin(DetailFieldsets, [], fieldsets: [default: ["name"]]), :show_body, @pax)
      end

      assert_raise RuntimeError, ~r/Invalid field:\n\n"name"/, fn ->
        render_plugin(plugin(DetailFieldsets, [], fieldsets: [default: [["name"]]]), :show_body, @pax)
      end
    end

    test "can be placed in one section, or a list of sections" do
      plugin = plugin(DetailFieldsets, [], placement: :show_footer_primary)
      assert count(render_plugin(plugin, :show_footer_primary, @pax), ".pax-detail-fieldsets") == 1
      assert render_plugin(plugin, :show_body, @pax) == ""

      plugin = plugin(DetailFieldsets, [], placement: [:show_footer_primary])
      assert count(render_plugin(plugin, :show_footer_primary, @pax), ".pax-detail-fieldsets") == 1
      assert render_plugin(plugin, :show_body, @pax) == ""
    end
  end
end
