defmodule Pax.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest
  import PaxTest.HTML, except: [to_html: 1]

  import Pax.Components

  test "render title" do
    assigns = %{}

    r = ~H"""
    <.pax_title>Test</.pax_title>
    """

    assert rendered_to_string(r) =~ ~S[class="pax-title pax-title-level-1"]
    assert rendered_to_string(r) =~ ~S[pax-title]
    assert rendered_to_string(r) =~ ~S[role="heading"]
    assert rendered_to_string(r) =~ ~S[aria-level="1"]
  end

  describe "assets/1" do
    test "includes the css and js with a cache busting hash" do
      assigns = %{}

      html = ~H"""
      <.assets />
      """

      assert attr(html, "link", "href") == ["/pax/assets/pax.css?vsn=#{Pax.Assets.current_hash(:css)}"]
      assert attr(html, "script", "src") == ["/pax/assets/pax.js?vsn=#{Pax.Assets.current_hash(:js)}"]
    end

    test "can be served from a different path" do
      assigns = %{}

      html = ~H"""
      <.assets at="/custom" />
      """

      assert [<<"/custom/assets/pax.css?vsn=", _::binary>>] = attr(html, "link", "href")
      assert [<<"/custom/assets/pax.js?vsn=", _::binary>>] = attr(html, "script", "src")
    end
  end

  describe "pax_title/1" do
    test "renders other levels and classes" do
      assigns = %{}

      html = ~H"""
      <.pax_title level={3} class="extra">Sub</.pax_title>
      """

      assert attr(html, "div", "class") == ["pax-title pax-title-level-3 extra"]
      assert attr(html, "div", "aria-level") == ["3"]
      assert text(html, "div") == "Sub"
    end
  end

  describe "pax_badge/1" do
    test "renders a span with extra attributes" do
      assigns = %{}

      html = ~H"""
      <.pax_badge class="new" title="Badge">3</.pax_badge>
      """

      assert attr(html, "span", "class") == ["pax-badge new"]
      assert attr(html, "span", "title") == ["Badge"]
      assert text(html, "span") == "3"
    end
  end

  describe "pax_link/1" do
    test "renders a Phoenix link" do
      assigns = %{}

      html = ~H"""
      <.pax_link navigate="/nav">Navigate</.pax_link>
      <.pax_link patch="/patch" class="extra">Patch</.pax_link>
      <.pax_link href="/href">Href</.pax_link>
      """

      assert attr(html, "a", "href") == ["/nav", "/patch", "/href"]
      assert attr(html, "a", "data-phx-link") == ["redirect", "patch"]
      assert attr(html, "a", "class") == ["pax-link", "pax-link extra", "pax-link"]
    end
  end

  describe "pax_button/1" do
    test "renders a button" do
      assigns = %{}

      html = ~H"""
      <.pax_button type="submit" phx-click="go">Go</.pax_button>
      """

      assert attr(html, "button", "type") == ["submit"]
      assert attr(html, "button", "phx-click") == ["go"]
      assert classes(html, "button") == ["pax-button"]
    end

    test "renders level, size and icon classes" do
      assigns = %{}

      html = ~H"""
      <.pax_button level={:primary} large icon class="extra">1</.pax_button>
      <.pax_button level={:secondary}>2</.pax_button>
      <.pax_button level={:tertiary}>3</.pax_button>
      """

      assert attr(html, "button", "class") == [
               "pax-button pax-button-large pax-button-icon pax-button-primary extra",
               "pax-button pax-button-secondary",
               "pax-button pax-button-tertiary"
             ]
    end

    test "renders a link styled like a button" do
      assigns = %{}

      html = ~H"""
      <.pax_button navigate="/nav" level={:primary}>Navigate</.pax_button>
      <.pax_button patch="/patch" large icon>Patch</.pax_button>
      <.pax_button href="/href" level={:tertiary} class="extra">Href</.pax_button>
      <.pax_button href="/href" level={:secondary}>Href</.pax_button>
      """

      assert count(html, "button") == 0
      assert attr(html, "a", "href") == ["/nav", "/patch", "/href", "/href"]

      assert attr(html, "a", "class") == [
               "pax-button pax-button-primary",
               "pax-button pax-button-large pax-button-icon",
               "pax-button pax-button-tertiary extra",
               "pax-button pax-button-secondary"
             ]
    end
  end

  describe "pax_select/1" do
    test "renders a select with the value selected" do
      assigns = %{}

      html = ~H"""
      <.pax_select id="s" name="page" value={2} options={[{"One", 1}, {"Two", 2}]} prompt="Pick" class="extra" />
      """

      assert attr(html, "select", "id") == ["s"]
      assert attr(html, "select", "class") == ["pax-select extra"]
      assert texts(html, "option") == ["Pick", "One", "Two"]
      assert attr(html, "option[selected]", "value") == ["2"]
    end

    test "renders errors and multiple selects" do
      assigns = %{}

      html = ~H"""
      <.pax_select name="tags[]" value={[]} options={["a"]} multiple has_errors disabled />
      """

      assert attr(html, "select", "class") == ["pax-select has-errors"]
      assert attr(html, "select", "multiple") == [""]
      assert attr(html, "select", "disabled") == [""]
      assert count(html, "option") == 1
    end
  end

  describe "pax_input/1" do
    test "renders an input" do
      assigns = %{}

      html = ~H"""
      <.pax_input id="i" name="q" value="find" placeholder="Search" class="extra" />
      """

      assert attr(html, "input", "type") == ["text"]
      assert attr(html, "input", "value") == ["find"]
      assert attr(html, "input", "placeholder") == ["Search"]
      assert attr(html, "input", "class") == ["pax-input extra"]
    end

    test "renders errors and other types" do
      assigns = %{}

      html = ~H"""
      <.pax_input name="d" type="date" value={~D[2024-01-02]} has_errors />
      """

      assert attr(html, "input", "type") == ["date"]
      assert attr(html, "input", "value") == ["2024-01-02"]
      assert attr(html, "input", "class") == ["pax-input has-errors"]
    end
  end

  describe "pax_header/1" do
    test "renders each slot in its own section" do
      assigns = %{}

      html = ~H"""
      <.pax_header class="extra">
        <:primary>One</:primary>
        <:secondary>Two</:secondary>
        <:tertiary>Three</:tertiary>
      </.pax_header>
      """

      assert attr(html, ".pax-header", "class") == ["pax-header extra"]
      assert text(html, ".pax-header-primary") == "One"
      assert text(html, ".pax-header-secondary") == "Two"
      assert text(html, ".pax-header-tertiary") == "Three"
    end
  end

  describe "pax_footer/1" do
    test "renders each slot in its own section" do
      assigns = %{}

      html = ~H"""
      <.pax_footer>
        <:primary>One</:primary>
        <:secondary>Two</:secondary>
        <:tertiary>Three</:tertiary>
      </.pax_footer>
      """

      assert text(html, ".pax-footer-primary") == "One"
      assert text(html, ".pax-footer-secondary") == "Two"
      assert text(html, ".pax-footer-tertiary") == "Three"
    end

    @tag :known_bug
    test "renders the class" do
      assigns = %{}

      html = ~H"""
      <.pax_footer class="extra"></.pax_footer>
      """

      assert attr(html, ".pax-footer", "class") == ["pax-footer extra"]
    end
  end

  describe "pax_table/1" do
    test "renders rows from a list" do
      assigns = %{rows: [%{id: 1, name: "One"}, %{id: 2, name: "Two"}]}

      html = ~H"""
      <.pax_table id="things" rows={@rows} row_id={&"thing-#{&1.id}"} row_item={& &1}>
        <:col :let={row} label="Id">{row.id}</:col>
        <:col :let={row} label="Name">{row.name}</:col>
      </.pax_table>
      """

      assert texts(html, "th") == ["Id", "Name"]
      assert attr(html, "tbody", "id") == ["things"]
      assert attr(html, "tbody", "phx-update") == []
      assert attr(html, "tr.pax-table-row", "id") == ["thing-1", "thing-2"]
      assert texts(html, "td") == ["1", "One", "2", "Two"]
      assert count(html, ".pax-table-row-actions") == 0
    end

    test "renders rows from a stream, with actions" do
      stream = Phoenix.LiveView.LiveStream.new(:things, "ref", [%{id: 1, name: "One"}], dom_id: &"thing-#{&1.id}")
      assigns = %{rows: stream}

      html = ~H"""
      <.pax_table id="things" rows={@rows}>
        <:col :let={row} label="Name">{row.name}</:col>
        <:action :let={row}>Edit {row.id}</:action>
      </.pax_table>
      """

      assert attr(html, "tbody", "phx-update") == ["stream"]
      assert attr(html, "tr.pax-table-row", "id") == ["thing-1"]
      assert count(html, "th.pax-table-actions-header") == 1
      assert text(html, ".pax-table-action") == "Edit 1"
    end
  end

  describe "component declarations" do
    # Declared attrs are what HEEx validates calls against at compile time, so check the public ones are declared
    test "public components declare their attributes and slots" do
      assert %{attrs: attrs} = Pax.Components.__components__()[:pax_button]
      assert Enum.map(attrs, & &1.name) |> Enum.sort() == [:class, :icon, :large, :level, :rest, :type]

      assert required_attrs(Pax.Interface.Components, :pax_interface) == [:pax]
      assert required_attrs(Pax.Field.Components, :pax_field_label) == [:field]
      assert required_attrs(Pax.Admin.Components, :admin_title) == [:pax_admin]
      assert %{slots: [%{name: :inner_block}]} = Pax.Plugins.DetailFieldsets.__components__()[:fieldset]
    end

    defp required_attrs(module, component) do
      for %{name: name, required: true} <- module.__components__()[component].attrs, do: name
    end

    test "modules without declarations have none" do
      for module <- [
            Pax.Admin.Dashboard.Components,
            Pax.Admin.Dashboard.Live,
            Pax.Admin.Layouts,
            Pax.Admin.Resource.Components,
            Pax.Admin.Resource.Live,
            Pax.Field.Boolean,
            Pax.Field.Date,
            Pax.Field.Datetime,
            Pax.Field.Float,
            Pax.Field.Integer,
            Pax.Field.String,
            Pax.Field.Time,
            Pax.Plugins.ActionButtons,
            Pax.Plugins.Breadcrumbs,
            Pax.Plugins.IndexTable,
            Pax.Plugins.Pagination,
            Pax.Plugins.Title
          ] do
        assert module.__components__() == %{}, "expected #{inspect(module)} to declare no components"
      end
    end
  end
end
