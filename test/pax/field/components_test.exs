defmodule Pax.Field.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2, to_form: 2]
  import PaxTest.HTML

  import Pax.Field.Components
  alias Pax.Field
  alias PaxTest.Book

  defp form(params \\ nil, action \\ nil) do
    changeset =
      if params do
        %Book{id: 1, title: "Dune"}
        |> Book.changeset(params)
        |> Ecto.Changeset.validate_number(:rank, greater_than: 0)
        |> Map.put(:action, action)
      else
        Ecto.Changeset.change(%Book{id: 1, title: "Dune", rank: 1})
      end

    to_form(changeset, as: :detail)
  end

  defp book, do: %Book{id: 1, title: "Dune", rank: 1}

  describe "pax_field_label/1" do
    test "renders the field's label, pointing at the field name without a form" do
      assigns = %{field: Field.init(nil, {:title, :string})}

      html = ~H"""
      <.pax_field_label field={@field} class="extra" />
      """

      assert text(html, "label") == "Title"
      assert attr(html, "label", "for") == ["title"]
      assert attr(html, "label", "class") == ["pax-field-label extra"]
    end

    test "points at the form input" do
      assigns = %{field: Field.init(nil, {:title, :string}), form: form()}

      html = ~H"""
      <.pax_field_label field={@field} form={@form} />
      """

      assert attr(html, "label", "for") == ["detail_title"]
    end

    test "accepts an explicit label and for" do
      assigns = %{field: Field.init(nil, {:title, :string})}

      html = ~H"""
      <.pax_field_label field={@field} label="Custom" for="custom" />
      """

      assert text(html, "label") == "Custom"
      assert attr(html, "label", "for") == ["custom"]
    end
  end

  describe "pax_field_link_or_text/1" do
    test "renders a link when the field has one" do
      assigns = %{field: Field.init(nil, {:title, :string, link: "/books/1"}), object: book()}

      html = ~H"""
      <.pax_field_link_or_text field={@field} object={@object} local_params={[page: 2]} link_class="l" text_class="t" />
      """

      assert attr(html, "a", "href") == ["/books/1?page=2"]
      assert attr(html, "a", "class") == ["pax-link pax-field-link l"]
      assert text(html, "a") == "Dune"
    end

    test "renders text when the field has no link" do
      assigns = %{field: Field.init(nil, {:title, :string}), object: book()}

      html = ~H"""
      <.pax_field_link_or_text field={@field} object={@object} link_class="l" text_class="t" />
      """

      assert count(html, "a") == 0
      assert attr(html, "div", "class") == ["pax-field-text t"]
      assert text(html, "div") == "Dune"
    end
  end

  describe "pax_field_text/1" do
    test "renders the value, or a bullet for nil" do
      assigns = %{title: Field.init(nil, {:title, :string}), rating: Field.init(nil, {:rating, :float}), object: book()}

      html = ~H"""
      <.pax_field_text field={@title} object={@object} />
      <.pax_field_text field={@rating} object={@object} />
      """

      assert texts(html, ".pax-field-text") == ["Dune", "•"]
    end
  end

  describe "pax_field_link/1" do
    test "resolves the link from the field when not given" do
      assigns = %{field: Field.init(nil, {:title, :string, link: &"/books/#{&1.id}"}), object: book()}

      html = ~H"""
      <.pax_field_link field={@field} object={@object} params={[a: 1]} class="extra" />
      """

      assert attr(html, "a", "href") == ["/books/1?a=1"]
      assert attr(html, "a", "data-phx-link") == ["redirect"]
      assert attr(html, "a", "class") == ["pax-link pax-field-link extra"]
    end

    test "uses the given link" do
      assigns = %{field: Field.init(nil, {:title, :string, link: "/ignored"}), object: book()}

      html = ~H"""
      <.pax_field_link field={@field} object={@object} link="/given" />
      """

      assert attr(html, "a", "href") == ["/given"]
    end
  end

  describe "pax_field_input_or_text/1" do
    test "renders text without a form" do
      assigns = %{field: Field.init(nil, {:title, :string}), object: book()}

      html = ~H"""
      <.pax_field_input_or_text field={@field} object={@object} text_class="t" input_class="i" />
      """

      assert count(html, "input") == 0
      assert attr(html, "div", "class") == ["pax-field-text t"]
    end

    test "renders text for immutable fields" do
      assigns = %{field: Field.init(nil, {:title, :string, immutable: true}), object: book(), form: form()}

      html = ~H"""
      <.pax_field_input_or_text field={@field} object={@object} form={@form} />
      """

      assert count(html, "input") == 0
      assert text(html, ".pax-field-text") == "Dune"
    end

    test "renders an input with errors for mutable fields" do
      assigns = %{field: Field.init(nil, {:title, :string}), object: book(), form: form(%{"title" => ""}, :validate)}

      html = ~H"""
      <.pax_field_input_or_text
        field={@field}
        object={@object}
        form={@form}
        input_class="i"
        errors_class="es"
        error_class="e"
      />
      """

      assert attr(html, "div.pax-field-input", "class") == ["pax-field-input i"]
      assert attr(html, "input", "class") == ["pax-input pax-field-control-input has-errors"]
      assert attr(html, ".pax-field-errors", "class") == ["pax-field-errors es"]
      assert attr(html, ".pax-field-error", "class") == ["pax-field-error e"]
      assert text(html, ".pax-field-error") == "can't be blank"
    end
  end

  describe "pax_field_input/1" do
    test "renders no errors for valid fields" do
      assigns = %{field: Field.init(nil, {:title, :string}), object: book(), form: form(%{"title" => "Ok"}, :validate)}

      html = ~H"""
      <.pax_field_input field={@field} object={@object} form={@form} />
      """

      assert attr(html, "input", "value") == ["Ok"]
      assert classes(html, "input") == ["pax-input pax-field-control-input"]
      assert count(html, ".pax-field-errors") == 0
    end
  end

  describe "pax_field_errors/1" do
    test "renders the given errors" do
      assigns = %{field: Field.init(nil, {:title, :string})}

      html = ~H"""
      <.pax_field_errors field={@field} errors={["one", "two"]} />
      """

      assert texts(html, ".pax-field-error") == ["one", "two"]
    end
  end

  describe "pax_field_control/1" do
    test "takes the id, name and value from the form field" do
      assigns = %{field: Field.init(nil, {:title, :string}), form: form()}

      html = ~H"""
      <.pax_field_control field={@field} form_field={@form[:title]} />
      """

      assert attr(html, "input", "id") == ["detail_title"]
      assert attr(html, "input", "name") == ["detail[title]"]
      assert attr(html, "input", "value") == ["Dune"]
    end

    test "can override the id, name and value" do
      assigns = %{field: Field.init(nil, {:title, :string}), form: form()}

      html = ~H"""
      <.pax_field_control field={@field} form_field={@form[:title]} id="i" name="n" value="v" />
      """

      assert attr(html, "input", "id") == ["i"]
      assert attr(html, "input", "name") == ["n"]
      assert attr(html, "input", "value") == ["v"]
    end

    test "appends [] to the name for multiple inputs" do
      assigns = %{field: Field.init(nil, {:title, :string}), form: form()}

      html = ~H"""
      <.pax_field_control field={@field} form_field={@form[:title]} multiple />
      """

      assert attr(html, "input", "name") == ["detail[title][]"]
    end

    test "renders without a form field" do
      assigns = %{field: Field.init(nil, {:title, :string})}

      html = ~H"""
      <.pax_field_control field={@field} name={nil} value="v" type="email" />
      <.pax_field_control field={@field} name="given" value="v" />
      """

      assert attr(html, "input", "name") == ["title", "given"]
      assert attr(html, "input", "type") == ["email", "text"]
    end

    test "renders checkboxes with errors, and an explicit checked" do
      assigns = %{field: Field.init(nil, {:in_print, :boolean})}

      html = ~H"""
      <.pax_field_control field={@field} type="checkbox" name="c" value="false" checked has_errors />
      """

      assert attr(html, "label", "class") == ["pax-checkbox-label pax-field-control-checkbox-label has-errors"]
      assert attr(html, "input[type=checkbox]", "checked") == [""]
      assert text(html, ".pax-field-control-checkbox-true") == "True"
      assert text(html, ".pax-field-control-checkbox-false") == "False"
    end
  end
end
