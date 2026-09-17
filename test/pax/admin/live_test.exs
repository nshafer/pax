defmodule Pax.Admin.LiveTest do
  use PaxTest.ConnCase, async: true

  import PaxTest.HTML, only: [texts: 2, attr: 3, classes: 2]

  alias PaxTest.Author
  alias PaxTest.Book
  alias PaxTest.Repo

  @authors [%Author{id: 1, name: "Ursula", born: 1929, active: true}, %Author{id: 99, name: "Octavia", active: false}]

  setup do
    Owner.put(:authors, @authors)
    :ok
  end

  describe "dashboard" do
    test "renders the layout with the config title, menu and breadcrumbs", %{conn: conn} do
      session =
        conn
        |> visit("/admin")
        |> assert_has("title", text: "Dashboard · Pax Admin")
        |> assert_has(".admin-title", text: "Test Admin")
        |> assert_has("main .pax-title", text: "Dashboard")
        |> assert_has(".admin-breadcrumbs a", text: "Dashboard")
        |> assert_has("a.admin-menu-link-dashboard.active", text: "Dashboard")

      assert texts(html(session), ".admin-menu > a.admin-menu-link") == ["Dashboard", "Books"]
      assert texts(html(session), ".admin-menu-section-button") == ["The Library", "Misc"]
      assert texts(html(session), "#admin_menu_section_library a") == ["Authors", "Members"]

      assert attr(html(session), "#admin_menu_section_misc a", "href") == [
               "/admin/misc/r/books",
               "/admin/misc/r/custom_render"
             ]

      assert classes(html(session), ".admin-menu-section") == ["admin-menu-section", "admin-menu-section"]
    end

    test "includes the pax assets in the root layout", %{conn: conn} do
      html = conn |> get("/admin") |> html_response(200)

      assert [
               <<"/pax/assets/pax.css?vsn=", _::binary>>,
               <<"/pax/admin/assets/pax_admin.css?vsn=", _::binary>>,
               fontawesome
             ] =
               attr(html, "link[rel=stylesheet]", "href")

      assert fontawesome =~ ~r"^/pax/static/fontawesome/css/all.*\.css$"

      assert [<<"/pax/assets/pax.js?vsn=", _::binary>>, <<"/pax/admin/assets/pax_admin.js?vsn=", _::binary>>] =
               attr(html, "script", "src")
    end

    test "uses the runtime config and resources", %{conn: conn} do
      session =
        conn
        |> visit("/runtime-admin")
        |> assert_has(".admin-title", text: "Runtime Admin")

      assert texts(html(session), ".admin-menu > a.admin-menu-link") == ["Dashboard", "Runtime Books"]
      assert texts(html(session), ".admin-menu-section-button") == ["Library", "The Archive"]
      assert attr(html(session), "#admin_menu_section_archive a", "href") == ["/runtime-admin/archive/r/books"]
    end

    test "uses the default title and a custom dashboard", %{conn: conn} do
      conn
      |> visit("/nested/custom")
      |> assert_has(".admin-title", text: "Pax Admin")
      |> assert_has("#custom-dashboard", text: "Custom dashboard for hooked")
    end

    test "can navigate to resources from the menu", %{conn: conn} do
      conn
      |> visit("/admin")
      |> click_link("#admin_menu_section_library a", "Authors")
      |> assert_path("/admin/library/r/authors")
      |> assert_has("main .pax-index-title", text: "Authors")
    end
  end

  describe "resources without an adapter" do
    test "index lists the objects with links", %{conn: conn} do
      conn
      |> visit("/admin/library/r/authors")
      |> assert_has("title", text: "Authors · Pax Admin")
      |> assert_has("#admin_menu_section_library.expanded a.admin-menu-link.active.indented", text: "Authors")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ The Library ❯ Authors")
      |> assert_has("td a[href='/admin/library/r/authors/1']", text: "Ursula")
      |> assert_has("td", text: "No")
      |> assert_has("a.pax-action-new-button[href='/admin/library/r/authors/new']", text: "New Author")
      |> assert_has(".pax-footer-primary", text: "Total: 2")

      assert_received {:author_resource, :init, %{"section" => "library", "resource" => "authors"}, %{}}
    end

    # Live patches update the title without the " · Pax Admin" suffix, which live_title adds in the browser
    test "show, edit and save", %{conn: conn} do
      conn
      |> visit("/admin/library/r/authors")
      |> click_link("Ursula")
      |> assert_path("/admin/library/r/authors/1")
      |> assert_has("title", text: "Ursula · Authors · Pax Admin")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ The Library ❯ Authors ❯ Ursula")
      |> assert_has(".pax-show-title", text: "Ursula")
      |> click_link("Edit")
      |> assert_path("/admin/library/r/authors/edit/1")
      |> assert_has("title", text: "Edit: Ursula · Authors")
      |> assert_has(".admin-breadcrumbs a[href='/admin/library/r/authors/1']", text: "Ursula")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ The Library ❯ Authors ❯ Ursula ❯ Edit")
      |> fill_in("Name", with: "Ursula K. Le Guin")
      |> click_button("Save")
      |> assert_path("/admin/library/r/authors/1")

      assert_received {:author_resource, :updated, %Author{id: 1, name: "Ursula K. Le Guin"}}
    end

    test "new and create", %{conn: conn} do
      conn
      |> visit("/admin/library/r/authors")
      |> click_link("New Author")
      |> assert_path("/admin/library/r/authors/new")
      |> assert_has("title", text: "New Author · Authors")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ The Library ❯ Authors ❯ New")
      |> fill_in("Name", with: "Octavia")
      |> click_button("Save")
      |> assert_path("/admin/library/r/authors/99")

      assert_received {:author_resource, :created, %Author{id: 99, name: "Octavia"}}
    end

    test "the resource init can skip pax", %{conn: conn} do
      Owner.put(:author_resource_init, fn _params, _session, socket -> {:skip, socket} end)

      conn
      |> visit("/admin/library/r/authors")
      |> assert_has(".admin-loading", text: "Loading...")
      |> assert_has("title", text: "Authors · Pax Admin")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard")
    end

    test "the resource init can redirect", %{conn: conn} do
      Owner.put(:author_resource_init, fn _params, _session, socket ->
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/admin")}
      end)

      conn
      |> visit("/admin/library/r/authors")
      |> assert_path("/admin")
      |> assert_has("main .pax-title", text: "Dashboard")
    end

    test "raises when the resource doesn't exist", %{conn: conn} do
      assert_raise Pax.Admin.ResourceNotFoundError, "resource nope not found", fn -> visit(conn, "/admin/r/nope") end

      assert_raise Pax.Admin.ResourceNotFoundError, "resource books not found in section library", fn ->
        visit(conn, "/admin/library/r/books")
      end
    end

    test "the delete action is not implemented", %{conn: conn} do
      assert_raise RuntimeError, "Delete action not implemented", fn ->
        visit(conn, "/admin/library/r/authors/delete/1")
      end
    end

    @tag :known_bug
    test "resources can render the page themselves", %{conn: conn} do
      conn
      |> visit("/admin/misc/r/custom_render")
      |> assert_has("#custom-resource-render")
    end
  end

  describe "resources with an adapter" do
    test "index uses the schema's fields and the repo", %{conn: conn} do
      Repo.stub(:aggregate, fn _query, :count -> 1 end)
      Repo.stub(:all, fn _query -> [%Book{id: 7, title: "Dune", rank: 1, in_print: true}] end)

      session =
        conn
        |> visit("/admin/r/books")
        |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ Books")
        |> assert_has("a.admin-menu-link.active", text: "Books")
        |> assert_has("td a[href='/admin/r/books/7']", text: "7")
        |> assert_has("td", text: "Dune")

      assert texts(html(session), "th") ==
               [
                 "Id",
                 "Title",
                 "Rank",
                 "Rating",
                 "In Print",
                 "Published",
                 "Read At",
                 "Uuid",
                 "Inserted At",
                 "Updated At"
               ]

      assert_received {Repo, :all, [query]}
      assert inspect(query) =~ "limit: ^100"
    end

    test "show and edit an object", %{conn: conn} do
      Repo.stub(:one!, fn _query -> %Book{id: 7, title: "Dune"} end)
      Owner.put(:book_resource_config, fields: [:title, {:rank, required: false}])

      conn
      |> visit("/admin/misc/r/books/7")
      |> assert_has("title", text: "Book 7 · More Books · Pax Admin")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ Misc ❯ More Books ❯ Book 7")
      |> click_link("Edit")
      |> assert_path("/admin/misc/r/books/edit/7")
      |> fill_in("Title", with: "Children of Dune")
      |> click_button("Save")
      |> assert_path("/admin/misc/r/books/7")

      assert_received {Repo, :update, [%Ecto.Changeset{changes: %{title: "Children of Dune"}}]}
    end

    test "the resource config overrides the admin's defaults", %{conn: conn} do
      Repo.stub(:aggregate, fn _query, :count -> 1 end)
      Repo.stub(:all, fn _query -> [%Book{id: 7, title: "Dune"}] end)

      Owner.put(:book_resource_config,
        fields: [{:title, link: true}],
        show_path: fn book, _socket -> "/elsewhere/#{book.id}" end,
        plural_name: "Novels"
      )

      conn
      |> visit("/admin/r/books")
      |> assert_has("td a[href='/elsewhere/7']", text: "Dune")
      |> assert_has(".pax-index-title", text: "Novels")
    end

    test "supports composite primary keys", %{conn: conn} do
      Repo.stub(:one!, fn _query -> %PaxTest.Membership{org_id: 1, user_id: 2, role: "admin"} end)

      conn
      |> visit("/admin/library/r/memberships/1/2")
      |> assert_has(".pax-show-title", text: "Membership org_id:1 user_id:2")
      |> assert_has("a.pax-action-edit-button[href='/admin/library/r/memberships/edit/1/2']")

      assert_received {Repo, :one!, [query]}
      assert inspect(query) =~ ~s(m0.org_id == ^"1")
      assert inspect(query) =~ ~s(m0.user_id == ^"2")
    end
  end
end
