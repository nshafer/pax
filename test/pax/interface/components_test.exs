defmodule Pax.Interface.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2, to_form: 2]
  import PaxTest.HTML

  import Pax.Interface.Components

  @sections %{
    index: ~w(index_header_primary index_header_secondary index_header_tertiary index_body
              index_footer_primary index_footer_secondary index_footer_tertiary),
    show: ~w(show_header_primary show_header_secondary show_header_tertiary show_body
             show_footer_primary show_footer_secondary show_footer_tertiary),
    edit: ~w(edit_header_primary edit_header_secondary edit_header_tertiary edit_body
             edit_footer_primary edit_footer_secondary edit_footer_tertiary),
    new: ~w(new_header_primary new_header_secondary new_header_tertiary new_body
            new_footer_primary new_footer_secondary new_footer_tertiary)
  }

  defp pax(action) do
    plugin = PaxTest.PluginHelpers.plugin(PaxTest.SpyPlugin)
    form = to_form(Ecto.Changeset.change(%PaxTest.Author{}), as: :detail)
    %Pax.Interface{action: action, plugins: [plugin], form: form}
  end

  describe "pax_interface/1" do
    for {action, sections} <- @sections do
      @action action
      @expected sections

      test "renders every #{action} section" do
        assigns = %{pax: pax(@action)}

        html = ~H"""
        <.pax_interface pax={@pax} class="ignored" index_class="i" show_class="s" edit_class="e" new_class="n" />
        """

        assert attr(html, ".spy", "data-section") == @expected
      end
    end

    test "renders the action's wrapper with its class" do
      for {action, selector, class} <- [
            {:index, ".pax-index", "pax-index i"},
            {:show, ".pax-detail-show", "pax-detail pax-detail-show s"},
            {:edit, "form.pax-detail-edit", "pax-detail pax-detail-edit e"},
            {:new, "form.pax-detail-new", "pax-detail pax-detail-new n"}
          ] do
        assigns = %{pax: pax(action)}

        html = ~H"""
        <.pax_interface pax={@pax} index_class="i" show_class="s" edit_class="e" new_class="n" />
        """

        assert classes(html, selector) == [class]
      end
    end

    test "renders forms for edit and new that validate and save" do
      for action <- [:edit, :new] do
        assigns = %{pax: pax(action)}

        html = ~H"""
        <.pax_interface pax={@pax} />
        """

        assert attr(html, "form", "id") == ["pax-detail-form"]
        assert attr(html, "form", "phx-change") == ["pax_validate"]
        assert attr(html, "form", "phx-submit") == ["pax_save"]
      end
    end

    test "renders nothing for other actions" do
      assigns = %{pax: pax(:delete)}

      html = ~H"""
      <.pax_interface pax={@pax} />
      """

      assert count(html, ".pax-interface > *") == 0
    end
  end
end
