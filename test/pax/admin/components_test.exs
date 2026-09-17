defmodule Pax.Admin.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import PaxTest.HTML

  import Pax.Admin.Components

  @resources PaxTest.Admin.__pax__(:resources)
  @books Enum.at(@resources, 0)
  @authors Enum.at(@resources, 1)

  defp admin(opts \\ []) do
    struct!(
      %Pax.Admin{admin_mod: PaxTest.Admin, config: %Pax.Admin.Config{}, resources: @resources, active: :dashboard},
      opts
    )
  end

  describe "assets/1 and fontawesome/1" do
    test "link to the admin assets" do
      assigns = %{}

      html = ~H"""
      <.assets at="/custom" />
      <.fontawesome at="/custom" />
      """

      assert [css, fontawesome] = attr(html, "link", "href")
      assert css == "/custom/admin/assets/pax_admin.css?vsn=#{Pax.Admin.Assets.current_hash(:css)}"
      assert fontawesome =~ ~r"^/custom/static/fontawesome/css/all.*\.css$"

      assert attr(html, "script", "src") == [
               "/custom/admin/assets/pax_admin.js?vsn=#{Pax.Admin.Assets.current_hash(:js)}"
             ]
    end
  end

  describe "admin_title/1" do
    test "uses the config title or a default" do
      assigns = %{with_title: admin(config: %Pax.Admin.Config{title: "Mine"}), without_title: admin()}

      html = ~H"""
      <.admin_title pax_admin={@with_title} />
      <.admin_title pax_admin={@without_title} />
      """

      assert texts(html, ".admin-title") == ["Mine", "Pax Admin"]
    end
  end

  describe "admin_header/1 and admin_sidebar/1" do
    test "only render the slots that are given" do
      assigns = %{}

      html = ~H"""
      <.admin_header>
        <:primary>One</:primary>
      </.admin_header>
      <.admin_header>
        <:secondary>Two</:secondary>
      </.admin_header>
      <.admin_sidebar>
        <:primary>Three</:primary>
      </.admin_sidebar>
      <.admin_sidebar>
        <:secondary>Four</:secondary>
      </.admin_sidebar>
      """

      assert texts(html, ".admin-header-section") == ["One", "Two"]
      assert texts(html, ".admin-sidebar-section") == ["Three", "Four"]
    end
  end

  describe "admin_breadcrumbs/1" do
    defp breadcrumbs(pax_admin, pax \\ nil, live_action \\ nil) do
      assigns = %{pax_admin: pax_admin, pax: pax, live_action: live_action}

      html = ~H"""
      <.admin_breadcrumbs pax_admin={@pax_admin} pax={@pax} live_action={@live_action} />
      """

      html
      |> parse()
      |> LazyHTML.query(".admin-breadcrumbs > *")
      |> Enum.map(&{LazyHTML.tag(&1), squish(LazyHTML.text(&1))})
    end

    test "renders nothing without an admin module" do
      assert breadcrumbs(%Pax.Admin{}) == []
    end

    test "links to the dashboard" do
      assert breadcrumbs(admin()) == [{["a"], "Dashboard"}]
      assert breadcrumbs(admin(resource: @authors)) == [{["a"], "Dashboard"}]
    end

    test "includes the section and resource" do
      pax = %Pax.Interface{index_path: "/admin/library/r/authors"}

      assert breadcrumbs(admin(resource: @authors), pax, :index) == [
               {["a"], "Dashboard"},
               {["div"], "❯"},
               {["div"], "The Library"},
               {["div"], "❯"},
               {["a"], "Authors"}
             ]

      assert breadcrumbs(admin(resource: @books), pax, :index) == [
               {["a"], "Dashboard"},
               {["div"], "❯"},
               {["a"], "Books"}
             ]
    end

    test "includes the action" do
      pax = %Pax.Interface{index_path: "/admin/r/books", object_name: "Dune", show_path: "/admin/r/books/1"}

      assert breadcrumbs(admin(resource: @books), pax, :new) |> Enum.drop(3) == [{["div"], "❯"}, {["div"], "New"}]
      assert breadcrumbs(admin(resource: @books), pax, :show) |> Enum.drop(3) == [{["div"], "❯"}, {["div"], "Dune"}]

      assert breadcrumbs(admin(resource: @books), pax, :edit) |> Enum.drop(3) == [
               {["div"], "❯"},
               {["a"], "Dune"},
               {["div"], "❯"},
               {["div"], "Edit"}
             ]

      assert breadcrumbs(admin(resource: @books), %{pax | show_path: nil}, :edit) |> Enum.drop(3) == [
               {["div"], "Dune"},
               {["div"], "❯"},
               {["div"], "Edit"}
             ]
    end
  end

  describe "admin_menu/1" do
    defp menu(pax_admin) do
      assigns = %{pax_admin: pax_admin}

      ~H"""
      <.admin_menu pax_admin={@pax_admin} />
      """
    end

    test "groups resources by section, in order" do
      resources = [
        %Pax.Admin.Resource{name: :a, path: "a", label: "A", section: nil, mod: nil, opts: []},
        @authors,
        %Pax.Admin.Resource{name: :b, path: "b", label: "B", section: nil, mod: nil, opts: []},
        %Pax.Admin.Resource{name: :c, path: "c", label: "C", section: nil, mod: nil, opts: []}
      ]

      html = menu(admin(resources: resources))

      assert classes(html, ".admin-menu > *") == [
               "admin-menu-link active admin-menu-link-dashboard",
               "admin-menu-link",
               "admin-menu-section",
               "admin-menu-link",
               "admin-menu-link"
             ]

      assert texts(html, ".admin-menu > a") == ["Dashboard", "A", "B", "C"]
      assert texts(html, ".admin-menu-section a") == ["Authors"]
    end

    test "marks the active resource and expands its section" do
      html = menu(admin(active: :resource, resource: @authors))

      assert classes(html, "a.admin-menu-link-dashboard") == ["admin-menu-link admin-menu-link-dashboard"]
      assert classes(html, "#admin_menu_section_library") == ["admin-menu-section expanded"]
      assert classes(html, "#admin_menu_section_misc") == ["admin-menu-section"]
      assert attr(html, "a.active", "href") == ["/admin/library/r/authors"]
      assert classes(html, "a.active") == ["admin-menu-link indented active"]
    end

    test "toggles sections" do
      html = menu(admin())
      [toggle | _] = attr(html, "button.admin-menu-section-button", "phx-click")

      assert toggle =~ "toggle_class"
      assert toggle =~ "#admin_menu_section_library"
    end

    test "truncates labels" do
      resource = %Pax.Admin.Resource{
        name: :a,
        path: "a",
        label: String.duplicate("a", 40),
        section: nil,
        mod: nil,
        opts: []
      }

      html = menu(admin(resources: [resource]))

      assert texts(html, ".admin-menu > a") |> List.last() == String.duplicate("a", 34) <> "…"
    end
  end

  describe "admin_menu_link/1" do
    test "renders a link with state classes" do
      assigns = %{}

      html = ~H"""
      <.admin_menu_link href="/x" active indented class="extra">X</.admin_menu_link>
      """

      assert classes(html, "a") == ["admin-menu-link indented active extra"]
    end
  end
end

defmodule Pax.Admin.Resource.LiveTest do
  use ExUnit.Case, async: true

  alias Pax.Admin.Resource.Live

  defmodule InvalidResource do
    use Pax.Admin.Resource

    def adapter(_socket), do: PaxTest.Owner.get(:adapter)
    def plugins(_socket), do: PaxTest.Owner.get(:plugins, [])
    def config(_socket), do: PaxTest.Owner.get(:config, [])
  end

  defmodule DefaultResource do
    use Pax.Admin.Resource
  end

  defp socket do
    resource = %Pax.Admin.Resource{name: :x, path: "x", label: "X", mod: InvalidResource, opts: []}
    Pax.Admin.assign_admin(%Phoenix.LiveView.Socket{}, admin_mod: PaxTest.Admin, resource: resource)
  end

  test "use Pax.Admin.Resource provides defaults for every callback" do
    socket = %Phoenix.LiveView.Socket{}

    assert DefaultResource.init(%{}, %{}, socket) == {:cont, socket}
    assert DefaultResource.adapter(socket) == nil
    assert DefaultResource.config(socket) == []

    assert DefaultResource.plugins(socket) == [
             Pax.Plugins.Title,
             {Pax.Plugins.Pagination, objects_per_page: 100},
             Pax.Plugins.IndexTable,
             Pax.Plugins.DetailList,
             Pax.Plugins.ActionButtons
           ]

    for {fun, args} <- [
          count_objects: [%{}, socket],
          list_objects: [%{}, socket],
          new_object: [socket],
          get_object: [%{}, %{}, socket],
          change_object: [%{}, %{}, socket],
          create_object: [%{}, nil, socket],
          update_object: [%{}, nil, socket]
        ] do
      assert apply(DefaultResource, fun, args) == :not_implemented
    end
  end

  describe "pax_adapter/1" do
    test "sets the resource as the callback module unless one is given" do
      PaxTest.Owner.put(:adapter, nil)
      assert Live.pax_adapter(socket()) == nil

      PaxTest.Owner.put(:adapter, PaxTest.FakeAdapter)
      assert Live.pax_adapter(socket()) == {PaxTest.FakeAdapter, InvalidResource, []}

      PaxTest.Owner.put(:adapter, {PaxTest.FakeAdapter, a: 1})
      assert Live.pax_adapter(socket()) == {PaxTest.FakeAdapter, InvalidResource, [a: 1]}

      PaxTest.Owner.put(:adapter, {PaxTest.FakeAdapter, Other, a: 1})
      assert Live.pax_adapter(socket()) == {PaxTest.FakeAdapter, Other, [a: 1]}
    end

    test "raises on an invalid adapter" do
      PaxTest.Owner.put(:adapter, "adapter")

      assert_raise ArgumentError, ~r/Invalid adapter returned from .*InvalidResource.adapter\/1/, fn ->
        Live.pax_adapter(socket())
      end
    end
  end

  test "pax_plugins/1 raises on invalid plugins" do
    PaxTest.Owner.put(:plugins, :plugins)

    assert_raise ArgumentError, ~r/Invalid plugins returned from .*InvalidResource.plugins\/1/, fn ->
      Live.pax_plugins(socket())
    end
  end

  describe "pax_config/1" do
    test "merges the resource config over the admin defaults" do
      PaxTest.Owner.put(:config, %{lookup_glob: "other", singular_name: "X"})

      assert %{lookup_glob: "other", singular_name: "X", index_path: index_path} = Live.pax_config(socket())
      assert index_path.(socket()) == "/admin/r/x"
    end

    test "raises on invalid config" do
      PaxTest.Owner.put(:config, "config")

      assert_raise ArgumentError, ~r/Invalid config returned from .*InvalidResource.config\/1/, fn ->
        Live.pax_config(socket())
      end
    end
  end
end
