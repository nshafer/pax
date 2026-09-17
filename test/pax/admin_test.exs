defmodule Pax.AdminTest do
  use ExUnit.Case, async: true

  alias Pax.Admin
  alias Pax.Admin.Config
  alias Pax.Admin.Resource
  alias Pax.Admin.Section
  alias PaxTest.Owner

  defp compile_admin(name, body) do
    Code.compile_string("""
    defmodule #{name} do
      use Pax.Admin, router: PaxTest.Router
      #{body}
    end
    """)
  end

  defp unique_name, do: "PaxTest.CompiledAdmin#{System.unique_integer([:positive])}"

  describe "use Pax.Admin" do
    test "exposes the router, path, config and resources" do
      assert PaxTest.Admin.__pax__(:router) == PaxTest.Router
      assert PaxTest.Admin.__pax__(:path) == "/admin"
      assert PaxTest.Admin.__pax__(:config) == %Config{title: "Test Admin"}

      assert PaxTest.CustomAdmin.__pax__(:path) == "/nested/custom"
      assert PaxTest.CustomAdmin.__pax__(:config) == nil
    end

    test "collects resources in order with their sections" do
      library = %Section{name: :library, path: "library", label: "The Library"}
      misc = %Section{name: :misc, path: "misc", label: "Misc"}

      assert PaxTest.Admin.__pax__(:resources) == [
               %Resource{
                 name: :books,
                 path: "books",
                 label: "Books",
                 section: nil,
                 mod: PaxTest.Admin.BookResource,
                 opts: []
               },
               %Resource{
                 name: :authors,
                 path: "authors",
                 label: "Authors",
                 section: library,
                 mod: PaxTest.Admin.AuthorResource,
                 opts: []
               },
               %Resource{
                 name: :memberships,
                 path: "memberships",
                 label: "Members",
                 section: library,
                 mod: PaxTest.Admin.MembershipResource,
                 opts: [label: "Members"]
               },
               %Resource{
                 name: :books,
                 path: "books",
                 label: "More Books",
                 section: misc,
                 mod: PaxTest.Admin.BookResource,
                 opts: [label: "More Books"]
               },
               %Resource{
                 name: :custom_render,
                 path: "custom_render",
                 label: "Custom Render",
                 section: misc,
                 mod: PaxTest.Admin.CustomRenderResource,
                 opts: []
               }
             ]
    end

    test "requires a router" do
      assert_raise RuntimeError, "missing :router option", fn ->
        Code.compile_string("defmodule #{unique_name()} do use Pax.Admin end")
      end
    end

    test "defines DashboardLive and ResourceLive" do
      assert Code.ensure_loaded?(PaxTest.Admin.DashboardLive)
      assert function_exported?(PaxTest.Admin.DashboardLive, :mount, 3)
      assert Code.ensure_loaded?(PaxTest.Admin.ResourceLive)
      assert function_exported?(PaxTest.Admin.ResourceLive, :pax_init, 3)
    end

    test "raises on nested sections" do
      assert_raise RuntimeError, "cannot embed section 'inner' inside another section 'outer'", fn ->
        compile_admin(unique_name(), """
        section :outer do
          section :inner do
          end
        end
        """)
      end
    end

    test "raises on duplicate sections" do
      assert_raise RuntimeError, "duplicate section 'library'", fn ->
        compile_admin(unique_name(), """
        section :library do
        end

        section :library do
        end
        """)
      end
    end

    test "raises on duplicate resources" do
      assert_raise RuntimeError, "duplicate resource 'books'", fn ->
        compile_admin(unique_name(), """
        resource :books, SomeResource
        resource :books, OtherResource
        """)
      end

      assert_raise RuntimeError, "duplicate resource 'books' in section 'library'", fn ->
        compile_admin(unique_name(), """
        section :library do
          resource :books, SomeResource
          resource :books, OtherResource
        end
        """)
      end
    end

    test "allows the same resource name in different sections" do
      name = unique_name()

      # The router doesn't mount this admin, which the type checker warns about
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        compile_admin(name, """
        config title: "Compiled"
        resource :books, SomeResource
        section :library do
          resource :books, SomeResource
        end
        Pax.Admin.__resource__(__MODULE__, :authors, SomeResource)
        """)
      end)

      module = Module.concat([name])
      assert module.__pax__(:config) == %Config{title: "Compiled"}

      assert [%Resource{section: nil}, %Resource{section: %Section{name: :library}}, %Resource{name: :authors}] =
               module.__pax__(:resources)
    end
  end

  describe "__config__/1" do
    test "accepts a config struct, nil, keyword list or map" do
      assert Admin.__config__(%Config{title: "A"}) == %Config{title: "A"}
      assert Admin.__config__(nil) == %Config{}
      assert Admin.__config__(title: "A") == %Config{title: "A"}
      assert Admin.__config__(%{title: "A"}) == [title: "A"]
    end

    test "raises on invalid config" do
      assert_raise RuntimeError, ~r/invalid config: \[made_up: 1\]: .*made_up/, fn -> Admin.__config__(made_up: 1) end
      assert_raise RuntimeError, "invalid config: 123", fn -> Admin.__config__(123) end
    end
  end

  describe "config_for/4" do
    test "uses the config/3 callback" do
      assert Admin.config_for(PaxTest.RuntimeAdmin, %{}, %{}, nil) == %Config{title: "Runtime Admin"}

      for {returned, expected} <- [
            {nil, %Config{}},
            {%Config{title: "Struct"}, %Config{title: "Struct"}},
            {[title: "List"], %Config{title: "List"}}
          ] do
        Owner.put(:runtime_admin_config, fn _, _, _ -> returned end)
        assert Admin.config_for(PaxTest.RuntimeAdmin, %{}, %{}, nil) == expected
      end
    end

    test "uses the config from the macros" do
      assert Admin.config_for(PaxTest.Admin, %{}, %{}, nil) == %Config{title: "Test Admin"}
      assert Admin.config_for(PaxTest.CustomAdmin, %{}, %{}, nil) == %Config{}
    end

    test "raises on invalid config" do
      Owner.put(:runtime_admin_config, fn _, _, _ -> "title" end)

      assert_raise RuntimeError, ~r/invalid config in Elixir.PaxTest.RuntimeAdmin: invalid config: "title"/, fn ->
        Admin.config_for(PaxTest.RuntimeAdmin, %{}, %{}, nil)
      end

      Owner.put(:runtime_admin_config, fn _, _, _ -> %{made_up: true} end)

      assert_raise RuntimeError, ~r/invalid config in Elixir.PaxTest.RuntimeAdmin/, fn ->
        Admin.config_for(PaxTest.RuntimeAdmin, %{}, %{}, nil)
      end
    end
  end

  describe "resources_for/4" do
    test "uses the resources from the macros" do
      assert Admin.resources_for(PaxTest.Admin, %{}, %{}, nil) == PaxTest.Admin.__pax__(:resources)
    end

    test "parses the resources/3 callback into the same structure as the macros" do
      assert Admin.resources_for(PaxTest.RuntimeAdmin, %{}, %{}, nil) == [
               %Resource{
                 name: :books,
                 path: "books",
                 label: "Runtime Books",
                 section: nil,
                 mod: PaxTest.Admin.BookResource,
                 opts: [extra: "option"]
               },
               %Resource{
                 name: :authors,
                 path: "authors",
                 label: "Authors",
                 section: %Section{name: :library, path: "library", label: "Library"},
                 mod: PaxTest.Admin.AuthorResource,
                 opts: []
               },
               %Resource{
                 name: :books,
                 path: "books",
                 label: "Books",
                 section: %Section{name: :archive, path: "archive", label: "The Archive"},
                 mod: PaxTest.Admin.BookResource,
                 opts: []
               }
             ]
    end

    defp resources_for(resources) do
      Owner.put(:runtime_admin_resources, fn _, _, _ -> resources end)
      Admin.resources_for(PaxTest.RuntimeAdmin, %{}, %{}, nil)
    end

    test "labels sections from their name by default" do
      assert [%Resource{section: %Section{name: :new_releases, label: "New Releases"}}] =
               resources_for(new_releases: %{resources: [books: %{resource: SomeResource}]})
    end

    test "raises when resources aren't a list" do
      assert_raise RuntimeError, "invalid resources format: %{}", fn -> resources_for(%{}) end
    end

    test "raises on nested sections" do
      assert_raise RuntimeError, "cannot embed section 'inner' inside another section 'outer'", fn ->
        resources_for(outer: [inner: [books: %{resource: SomeResource}]])
      end

      assert_raise RuntimeError, "cannot embed section 'inner' inside another section 'outer'", fn ->
        resources_for(outer: [inner: %{resources: []}])
      end
    end

    test "raises on invalid resources" do
      assert_raise RuntimeError, ~r/invalid resource :books: '%{mod: SomeResource}' in section ':library'/, fn ->
        resources_for(library: [books: %{mod: SomeResource}])
      end

      assert_raise RuntimeError, ~r/invalid resource "books" in section ':library'/, fn ->
        resources_for(library: ["books"])
      end
    end

    test "raises on invalid top level resources" do
      assert_raise RuntimeError, "invalid resource :books: '%{mod: SomeResource}'", fn ->
        resources_for(books: %{mod: SomeResource})
      end

      assert_raise RuntimeError, ~s(invalid resource "books"), fn -> resources_for(["books"]) end
    end

    test "raises on duplicate resources, like the macros" do
      assert_raise RuntimeError, "duplicate resource 'books'", fn ->
        resources_for(books: %{resource: SomeResource}, authors: %{resource: SomeResource}, books: %{resource: Other})
      end

      assert_raise RuntimeError, "duplicate resource 'books' in section 'library'", fn ->
        resources_for(library: [books: %{resource: SomeResource}, books: %{resource: Other}])
      end
    end

    test "raises on duplicate sections, like the macros" do
      assert_raise RuntimeError, "duplicate section 'library'", fn ->
        resources_for(library: [books: %{resource: SomeResource}], library: %{resources: [authors: %{resource: Other}]})
      end
    end

    test "allows the same resource name at the top level and in different sections" do
      resources =
        resources_for(
          books: %{resource: SomeResource},
          library: [books: %{resource: SomeResource}],
          archive: %{resources: [books: %{resource: SomeResource}]}
        )

      assert Enum.map(resources, &{&1.section && &1.section.name, &1.name}) == [
               {nil, :books},
               {:library, :books},
               {:archive, :books}
             ]
    end
  end

  describe "match_resource/3" do
    setup do
      %{resources: PaxTest.Admin.__pax__(:resources)}
    end

    test "matches by name or path, with or without a section", %{resources: resources} do
      assert %Resource{name: :books, section: nil} = Admin.match_resource(resources, nil, :books)
      assert %Resource{name: :books, section: nil} = Admin.match_resource(resources, nil, "books")
      assert %Resource{label: "More Books"} = Admin.match_resource(resources, :misc, :books)
      assert %Resource{label: "More Books"} = Admin.match_resource(resources, "misc", "books")
    end

    test "returns nil when there is no match", %{resources: resources} do
      assert Admin.match_resource(resources, nil, :authors) == nil
      assert Admin.match_resource(resources, "library", "books") == nil
    end
  end

  describe "paths and urls" do
    test "dashboard" do
      assert Admin.dashboard_path(PaxTest.Admin) == "/admin"
      assert PaxTest.Admin.dashboard_path() == "/admin"
    end

    test "resource paths without a section" do
      assert Admin.resource_index_path(PaxTest.Admin, :books) == "/admin/r/books"
      assert Admin.resource_new_path(PaxTest.Admin, "books") == "/admin/r/books/new"
      assert Admin.resource_show_path(PaxTest.Admin, :books, [1]) == "/admin/r/books/1"
      assert Admin.resource_edit_path(PaxTest.Admin, :books, [1, "a b/c"]) == "/admin/r/books/edit/1/a%20b%2Fc"
    end

    test "resource paths with a section" do
      [_, resource | _] = PaxTest.Admin.__pax__(:resources)

      assert Admin.resource_index_path(PaxTest.Admin, :library, :authors) == "/admin/library/r/authors"
      assert Admin.resource_new_path(PaxTest.Admin, resource.section, resource) == "/admin/library/r/authors/new"
      assert Admin.resource_show_path(PaxTest.Admin, "library", "authors", [1]) == "/admin/library/r/authors/1"

      assert Admin.resource_edit_path(PaxTest.Admin, resource.section, resource, [1]) ==
               "/admin/library/r/authors/edit/1"
    end

    test "raises on invalid sections and resources" do
      assert_raise RuntimeError, "invalid section path: 123", fn ->
        Admin.resource_index_path(PaxTest.Admin, 123, :books)
      end

      assert_raise RuntimeError, "invalid resource path: 123", fn -> Admin.resource_index_path(PaxTest.Admin, 123) end
    end

    test "the admin module's path functions" do
      assert PaxTest.Admin.resource_index_path(:books) == "/admin/r/books"
      assert PaxTest.Admin.resource_index_path(:library, :authors) == "/admin/library/r/authors"
      assert PaxTest.Admin.resource_show_path(:books, [1]) == "/admin/r/books/1"
      assert PaxTest.Admin.resource_show_path(:library, :authors, [1]) == "/admin/library/r/authors/1"
      assert PaxTest.Admin.resource_edit_path(:books, [1]) == "/admin/r/books/edit/1"
      assert PaxTest.Admin.resource_edit_path(:library, :authors, [1]) == "/admin/library/r/authors/edit/1"
    end

    test "urls" do
      endpoint = PaxTest.Endpoint

      assert Admin.resource_index_url(PaxTest.Admin, endpoint, nil, :books) == "http://localhost/admin/r/books"

      assert Admin.resource_new_url(PaxTest.Admin, endpoint, :library, :authors) ==
               "http://localhost/admin/library/r/authors/new"

      assert Admin.resource_show_url(PaxTest.Admin, endpoint, :books, [1]) == "http://localhost/admin/r/books/1"
      assert Admin.resource_edit_url(PaxTest.Admin, endpoint, :books, [1]) == "http://localhost/admin/r/books/edit/1"

      assert PaxTest.Admin.resource_index_url(endpoint, :books) == "http://localhost/admin/r/books"

      assert PaxTest.Admin.resource_index_url(endpoint, :library, :authors) ==
               "http://localhost/admin/library/r/authors"

      assert PaxTest.Admin.resource_new_url(endpoint, :books) == "http://localhost/admin/r/books/new"

      assert PaxTest.Admin.resource_show_url(URI.parse("https://example.com"), :books, [1]) ==
               "https://example.com/admin/r/books/1"

      assert PaxTest.Admin.resource_edit_url(endpoint, :library, :authors, [1]) ==
               "http://localhost/admin/library/r/authors/edit/1"
    end
  end

  describe "assign_admin/3" do
    test "assigns into the admin struct on a socket" do
      socket =
        %Phoenix.LiveView.Socket{} |> Admin.assign_admin(:active, :dashboard) |> Admin.assign_admin(config: %Config{})

      assert socket.assigns.pax_admin == %Admin{active: :dashboard, config: %Config{}}
    end

    test "assigns into the admin struct in an assigns map" do
      assigns = %{__changed__: %{}, pax: %Pax.Interface{}, pax_admin: %Admin{active: :resource}}
      assigns = Admin.assign_admin(assigns, :config, %Config{})

      assert assigns.pax_admin == %Admin{active: :resource, config: %Config{}}
    end
  end
end

defmodule Pax.Admin.RouterTest do
  use ExUnit.Case, async: true

  defmodule Router do
    use Phoenix.Router
    use Pax.Admin.Router
    import Phoenix.LiveView.Router

    pax_admin "/one", PaxTest.Admin

    scope "/scoped", PaxTest do
      pax_admin "/two", RuntimeAdmin,
        as: :two,
        root_layout: {MyLayouts, :root},
        layout: false,
        on_mount: PaxTest.CustomAdmin.Hook,
        session: %{"key" => "value"}
    end
  end

  defp live_route(path) do
    %{phoenix_live_view: {view, action, opts, live_session}} =
      Phoenix.Router.route_info(Router, "GET", path, "localhost")

    %{view: view, action: action, as: opts[:as], live_session: live_session}
  end

  test "records the full path of each admin" do
    assert Router.__pax__(:paths) == %{PaxTest.Admin => "/one", PaxTest.RuntimeAdmin => "/scoped/two"}
  end

  test "generates dashboard and resource routes, with and without sections" do
    for {path, view, action} <- [
          {"/one", PaxTest.Admin.DashboardLive, :dashboard},
          {"/one/r/books", PaxTest.Admin.ResourceLive, :index},
          {"/one/r/books/new", PaxTest.Admin.ResourceLive, :new},
          {"/one/r/books/edit/1/2", PaxTest.Admin.ResourceLive, :edit},
          {"/one/r/books/delete/1", PaxTest.Admin.ResourceLive, :delete},
          {"/one/r/books/1/2", PaxTest.Admin.ResourceLive, :show},
          {"/one/library/r/authors", PaxTest.Admin.ResourceLive, :index},
          {"/one/library/r/authors/new", PaxTest.Admin.ResourceLive, :new},
          {"/one/library/r/authors/edit/1", PaxTest.Admin.ResourceLive, :edit},
          {"/one/library/r/authors/delete/1", PaxTest.Admin.ResourceLive, :delete},
          {"/one/library/r/authors/1", PaxTest.Admin.ResourceLive, :show}
        ] do
      assert %{view: ^view, action: ^action} = live_route(path)
    end
  end

  test "infers the route helper names and default layouts" do
    assert %{as: :admin_dashboard, live_session: session} = live_route("/one")
    assert %{as: :admin_resource} = live_route("/one/r/books")
    assert session.name == PaxTest.Admin
    assert session.extra == %{root_layout: {Pax.Admin.Layouts, :root}, layout: {Pax.Admin.Layouts, :admin}}
  end

  test "accepts options for the helper names and live session" do
    assert %{as: :two_dashboard, view: PaxTest.RuntimeAdmin.DashboardLive, live_session: session} =
             live_route("/scoped/two")

    assert %{as: :two_resource} = live_route("/scoped/two/r/books")

    assert %{root_layout: {MyLayouts, :root}, layout: false, on_mount: [%{id: {PaxTest.CustomAdmin.Hook, :default}}]} =
             session.extra

    assert session.extra.session == %{"key" => "value"}
  end

  test "requires :as when it can't be inferred from the admin module" do
    assert_raise ArgumentError, ~r/could not infer :as option from Elixir.PaxTest.Owner/, fn ->
      Code.compile_string("""
      defmodule PaxTest.BadAdminRouter#{System.unique_integer([:positive])} do
        use Phoenix.Router
        use Pax.Admin.Router
        import Phoenix.LiveView.Router

        pax_admin "/bad", PaxTest.Owner
      end
      """)
    end
  end

  test "infers :as from nested admin modules" do
    {full_path, admin_mod, modules, opts} = compile_and_capture("PaxTest.MainAdmin.Nested")

    assert full_path == "/nested"
    assert admin_mod == PaxTest.MainAdmin.Nested

    assert modules == %{
             dashboard: PaxTest.MainAdmin.Nested.DashboardLive,
             resource: PaxTest.MainAdmin.Nested.ResourceLive
           }

    assert opts.dashboard == [as: :main_admin_nested_dashboard]
  end

  # __pax_admin__/4 needs a router that is still compiling, so capture its result from inside one
  defp compile_and_capture(admin) do
    name = "PaxTest.CaptureRouter#{System.unique_integer([:positive])}"

    module = Module.concat([name])

    Code.compile_string("""
    defmodule #{name} do
      use Phoenix.Router
      @result Pax.Admin.Router.__pax_admin__(__MODULE__, "/nested", #{admin}, [])
      def result, do: @result
    end
    """)

    module.result()
  end
end
