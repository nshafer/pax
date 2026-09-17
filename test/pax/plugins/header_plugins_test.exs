defmodule Pax.Plugins.TitleTest do
  use ExUnit.Case, async: true

  import PaxTest.HTML
  import PaxTest.PluginHelpers
  alias Pax.Plugins.Title

  @pax %Pax.Interface{singular_name: "Book", plural_name: "Books", object_name: "Dune"}

  test "has a valid config spec" do
    assert {:ok, _} = Pax.Config.validate(Title.config_spec(), %{}, validate_config_spec: true)
  end

  describe "render/3" do
    test "renders a title for each action in its header by default" do
      plugin = plugin(Title)

      assert text(render_plugin(plugin, :index_header_primary, %{@pax | action: :index}), ".pax-index-title") == "Books"
      assert text(render_plugin(plugin, :show_header_primary, %{@pax | action: :show}), ".pax-show-title") == "Dune"

      assert text(render_plugin(plugin, :edit_header_primary, %{@pax | action: :edit}), ".pax-edit-title") ==
               "Edit: Dune"

      assert text(render_plugin(plugin, :new_header_primary, %{@pax | action: :new}), ".pax-new-title") == "New Book"

      assert text(render_plugin(plugin, :delete_header_primary, %{@pax | action: :delete}), ".pax-delete-title") ==
               "Delete: Dune"
    end

    test "renders nothing in other sections, or for other actions" do
      plugin = plugin(Title)

      assert render_plugin(plugin, :index_body, %{@pax | action: :index}) == ""
      assert render_plugin(plugin, :index_header_primary, %{@pax | action: :other}) == ""
    end

    test "truncates the title" do
      plugin = plugin(Title, truncate_length: 3)
      assert text(render_plugin(plugin, :show_header_primary, %{@pax | action: :show}), ".pax-title") == "Du…"

      plugin = plugin(Title, [], truncate_length: fn _socket -> 4 end)
      assert text(render_plugin(plugin, :index_header_primary, %{@pax | action: :index}), ".pax-title") == "Boo…"
    end

    test "can be placed in one section, or a list of sections" do
      plugin = plugin(Title, placement: :index_body)
      assert text(render_plugin(plugin, :index_body, %{@pax | action: :index}), ".pax-title") == "Books"
      assert render_plugin(plugin, :index_header_primary, %{@pax | action: :index}) == ""

      plugin = plugin(Title, [], placement: fn _socket -> [:index_footer_primary] end)
      assert text(render_plugin(plugin, :index_footer_primary, %{@pax | action: :index}), ".pax-title") == "Books"
      assert render_plugin(plugin, :index_header_primary, %{@pax | action: :index}) == ""
    end
  end
end

defmodule Pax.Plugins.BreadcrumbsTest do
  use ExUnit.Case, async: true

  import PaxTest.HTML
  import PaxTest.PluginHelpers
  alias Pax.Plugins.Breadcrumbs

  @pax %Pax.Interface{action: :show, plural_name: "Books", object_name: "Dune", index_path: "/books?page=2"}

  test "has a valid config spec" do
    assert {:ok, _} = Pax.Config.validate(Breadcrumbs.config_spec(), %{}, validate_config_spec: true)
  end

  describe "render/3" do
    test "links to the index in the detail headers by default" do
      plugin = plugin(Breadcrumbs)

      for section <- [:show_header_primary, :edit_header_primary, :new_header_primary, :delete_header_primary] do
        html = render_plugin(plugin, section, @pax)

        assert attr(html, "a.pax-breadcrumbs-link", "href") == ["/books?page=2"]
        assert text(html, "a.pax-breadcrumbs-link") == "Books"
        assert text(html, ".pax-breadcrumbs-separator") == "/"
      end

      assert render_plugin(plugin, :index_header_primary, @pax) == ""
    end

    test "renders nothing without an index path" do
      assert count(render_plugin(plugin(Breadcrumbs), :show_header_primary, %{@pax | index_path: nil}), "div") == 0
    end

    test "leaves out the separator without an object name" do
      html = render_plugin(plugin(Breadcrumbs), :new_header_primary, %{@pax | object_name: nil})
      assert count(html, ".pax-breadcrumbs-separator") == 0
    end

    test "truncates the index title" do
      html = render_plugin(plugin(Breadcrumbs, [], truncate_length: 3), :show_header_primary, @pax)
      assert text(html, "a") == "Bo…"
    end

    test "can be placed in one section" do
      plugin = plugin(Breadcrumbs, [], placement: :show_body)

      assert text(render_plugin(plugin, :show_body, @pax), "a") == "Books"
      assert render_plugin(plugin, :show_header_primary, @pax) == ""
    end
  end
end

defmodule Pax.Plugins.ActionButtonsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]
  import PaxTest.HTML
  import PaxTest.PluginHelpers
  alias Pax.Plugins.ActionButtons

  @form to_form(Ecto.Changeset.change(%PaxTest.Author{}), as: :detail)

  @pax %Pax.Interface{
    singular_name: "Book",
    index_path: "/books",
    new_path: "/books/new",
    show_path: "/books/1",
    edit_path: "/books/1/edit"
  }

  test "has a valid config spec" do
    assert {:ok, _} = Pax.Config.validate(ActionButtons.config_spec(), %{}, validate_config_spec: true)
  end

  describe "new button" do
    test "links to the new path in the index header" do
      html = render_plugin(plugin(ActionButtons), :index_header_secondary, %{@pax | action: :index})

      assert attr(html, "a.pax-action-new-button", "href") == ["/books/new"]
      assert attr(html, "a.pax-action-new-button", "data-phx-link") == ["patch"]
      assert text(html, "a.pax-action-new-button") == "New Book"
    end

    test "is not rendered without a new path" do
      html = render_plugin(plugin(ActionButtons), :index_header_secondary, %{@pax | action: :index, new_path: nil})
      assert count(html, "a") == 0
    end

    test "truncates the name" do
      html = render_plugin(plugin(ActionButtons, truncate_length: 3), :index_header_secondary, %{@pax | action: :index})
      assert text(html, "a") == "New Bo…"
    end

    test "can be placed in a list of sections" do
      plugin = plugin(ActionButtons, [], new_button_placement: [:index_header_primary, :index_footer_primary])

      assert count(render_plugin(plugin, :index_header_primary, @pax), "a.pax-action-new-button") == 1
      assert count(render_plugin(plugin, :index_footer_primary, @pax), "a.pax-action-new-button") == 1
      assert count(render_plugin(plugin, :index_header_secondary, @pax), "a.pax-action-new-button") == 0
      assert count(render_plugin(plugin, :index_header_primary, %{@pax | new_path: nil}), "a") == 0
    end
  end

  describe "edit button" do
    test "links to the edit path in the show header" do
      html = render_plugin(plugin(ActionButtons), :show_header_secondary, %{@pax | action: :show})

      assert attr(html, "a.pax-action-edit-button", "href") == ["/books/1/edit"]
      assert text(html, "a.pax-action-edit-button") == "Edit"
      assert count(html, "a") == 1
    end

    test "is not rendered without an edit path" do
      html = render_plugin(plugin(ActionButtons), :show_header_secondary, %{@pax | edit_path: nil})
      assert count(html, "a.pax-action-edit-button") == 0
    end

    test "can be placed in a list of sections" do
      plugin = plugin(ActionButtons, [], edit_button_placement: fn _ -> [:show_footer_secondary] end)

      assert count(render_plugin(plugin, :show_footer_secondary, @pax), "a.pax-action-edit-button") == 1
      assert count(render_plugin(plugin, :show_header_secondary, @pax), "a.pax-action-edit-button") == 0
      assert count(render_plugin(plugin, :show_footer_secondary, %{@pax | edit_path: nil}), "a") == 0
    end
  end

  describe "cancel and save buttons" do
    test "are rendered in the edit and new headers" do
      for section <- [:edit_header_secondary, :new_header_secondary] do
        html = render_plugin(plugin(ActionButtons), section, %{@pax | form: @form})

        assert attr(html, "a.pax-action-edit-cancel-button", "href") == ["/books/1"]
        assert text(html, "a.pax-action-edit-cancel-button") == "Cancel"
        assert attr(html, "button.pax-action-edit-save-button", "type") == ["submit"]
        assert attr(html, "button.pax-action-edit-save-button", "name") == ["detail[save]"]
        assert text(html, "button.pax-action-edit-save-button") == "Save"
      end
    end

    test "cancel goes to the show path, then the index path, or isn't rendered" do
      html = render_plugin(plugin(ActionButtons), :new_header_secondary, %{@pax | show_path: nil})
      assert attr(html, "a.pax-action-edit-cancel-button", "href") == ["/books"]

      html = render_plugin(plugin(ActionButtons), :new_header_secondary, %{@pax | show_path: nil, index_path: nil})
      assert count(html, "a.pax-action-edit-cancel-button") == 0
    end

    test "save is only rendered with a form" do
      html = render_plugin(plugin(ActionButtons), :edit_header_secondary, @pax)
      assert count(html, "button") == 0
    end

    test "can be placed in one section" do
      config = [edit_cancel_button_placement: :edit_footer_primary, edit_save_button_placement: :edit_footer_secondary]
      plugin = plugin(ActionButtons, [], config)
      pax = %{@pax | form: @form}

      assert count(render_plugin(plugin, :edit_footer_primary, pax), "a.pax-action-edit-cancel-button") == 1
      assert count(render_plugin(plugin, :edit_footer_secondary, pax), "button.pax-action-edit-save-button") == 1
      assert count(render_plugin(plugin, :edit_header_secondary, pax), "a, button") == 0
    end
  end
end
