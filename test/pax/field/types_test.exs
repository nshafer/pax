defmodule Pax.Field.TypesTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import PaxTest.HTML
  alias Pax.Field

  defp form_field(name, data) do
    types = %{name => :any}
    form = to_form(Ecto.Changeset.change({data, types}), as: :detail)
    form[name]
  end

  defp input(type, name, value, opts \\ []) do
    field = Field.init(nil, {name, type, opts})
    field.type.input(field.opts, field, form_field(name, %{name => value}))
  end

  describe "Pax.Field.Boolean" do
    test "renders true and false with configurable text" do
      opts = Field.Boolean.init([])
      assert Field.Boolean.render(opts, true) == "True"
      assert Field.Boolean.render(opts, false) == "False"
      assert Field.Boolean.render(opts, nil) == "False"

      opts = Field.Boolean.init(true: "Yes", false: "No")
      assert Field.Boolean.render(opts, true) == "Yes"
      assert Field.Boolean.render(opts, false) == "No"
    end

    test "renders a checkbox input with a hidden false value" do
      html = input(:boolean, :in_print, true, true: "Yes", false: "No")

      assert attr(html, "input[type=hidden]", "value") == ["false"]
      assert attr(html, "input[type=checkbox]", "id") == ["detail_in_print"]
      assert attr(html, "input[type=checkbox]", "checked") == [""]
      assert text(html, ".pax-field-control-checkbox-true") == "Yes"
      assert text(html, ".pax-field-control-checkbox-false") == "No"

      html = input(:boolean, :in_print, false)
      assert count(html, "input[type=checkbox][checked]") == 0
    end
  end

  describe "Pax.Field.Date" do
    test "renders with a configurable format" do
      assert Field.Date.render(Field.Date.init([]), ~D[2024-02-03]) == "Sat, February 03, 2024"
      assert Field.Date.render(Field.Date.init(format: "%Y/%m/%d"), ~D[2024-02-03]) == "2024/02/03"
      assert Field.Date.render(Field.Date.init([]), nil) == nil
    end

    test "renders a date input" do
      html = input(:date, :published, ~D[2024-02-03])
      assert attr(html, "input", "type") == ["date"]
      assert attr(html, "input", "value") == ["2024-02-03"]
    end
  end

  describe "Pax.Field.Datetime" do
    test "renders the date and time separately by default" do
      html = Field.Datetime.render(Field.Datetime.init([]), ~N[2024-02-03 14:05:00])
      assert texts(html, "span") == ["Sat, February 03, 2024", "02:05 PM"]
      assert Field.Datetime.render(Field.Datetime.init([]), nil) == nil
    end

    test "renders with a single format" do
      opts = Field.Datetime.init(format: "%Y-%m-%d %H:%M")
      assert Field.Datetime.render(opts, ~U[2024-02-03 14:05:00Z]) == "2024-02-03 14:05"
    end

    @tag :known_bug
    test "renders with separate date and time formats" do
      opts = Field.Datetime.init(date_format: "%Y-%m-%d", time_format: "%H:%M")
      html = Field.Datetime.render(opts, ~N[2024-02-03 14:05:00])
      assert texts(html, "span") == ["2024-02-03", "14:05"]
    end

    test "renders a datetime-local input" do
      html = input(:datetime, :inserted_at, ~N[2024-02-03 14:05:00])
      assert attr(html, "input", "type") == ["datetime-local"]
      assert attr(html, "input", "value") == ["2024-02-03T14:05"]
    end
  end

  describe "Pax.Field.Float" do
    test "renders with optional rounding" do
      assert Field.Float.render(Field.Float.init([]), 1.23456) == "1.23456"
      assert Field.Float.render(Field.Float.init(round: 2), 1.23456) == "1.23"
      assert Field.Float.render(Field.Float.init([]), nil) == nil
    end

    test "renders a numeric text input" do
      html = input(:float, :rating, 4.5)
      assert attr(html, "input", "type") == ["text"]
      assert attr(html, "input", "inputmode") == ["numeric"]
      assert attr(html, "input", "pattern") == ["[0-9\\.\\-]*"]
      assert attr(html, "input", "value") == ["4.5"]
    end
  end

  describe "Pax.Field.Integer" do
    test "renders the integer" do
      assert Field.Integer.render(Field.Integer.init([]), 42) == "42"
      assert Field.Integer.render(Field.Integer.init([]), nil) == nil
    end

    test "renders a numeric text input" do
      html = input(:integer, :rank, 42)
      assert attr(html, "input", "inputmode") == ["numeric"]
      assert attr(html, "input", "pattern") == ["[0-9]*"]
      assert attr(html, "input", "value") == ["42"]
    end
  end

  describe "Pax.Field.String" do
    test "renders with optional truncation" do
      assert Field.String.render(Field.String.init([]), "hello world") == "hello world"
      assert Field.String.render(Field.String.init([]), :atom) == "atom"
      assert Field.String.render(Field.String.init(truncate: 5), "hello world") == "hell…"
      assert Field.String.render(Field.String.init([]), nil) == nil
    end

    test "renders a text input" do
      html = input(:string, :title, "Dune")
      assert attr(html, "input", "type") == ["text"]
      assert attr(html, "input", "name") == ["detail[title]"]
      assert attr(html, "input", "id") == ["detail_title"]
      assert attr(html, "input", "value") == ["Dune"]
    end
  end

  describe "Pax.Field.Time" do
    test "renders with a configurable format" do
      assert Field.Time.render(Field.Time.init([]), ~T[14:05:00]) == "02:05 PM"
      assert Field.Time.render(Field.Time.init(format: "%H:%M"), ~T[14:05:00]) == "14:05"
      assert Field.Time.render(Field.Time.init([]), nil) == nil
    end

    test "renders a time input" do
      html = input(:time, :read_at, ~T[14:05:00])
      assert attr(html, "input", "type") == ["time"]
      assert attr(html, "input", "value") == ["14:05:00"]
    end
  end
end
