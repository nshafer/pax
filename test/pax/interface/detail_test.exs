defmodule Pax.Interface.DetailTest do
  use PaxTest.ConnCase, async: true

  alias Pax.Interface.Detail
  alias PaxTest.Author
  alias PaxTest.FakeAdapter

  @author %Author{id: 1, name: "Ursula", born: 1929, active: true}

  @plugins [Pax.Plugins.Title, Pax.Plugins.DetailList, Pax.Plugins.ActionButtons, Pax.Plugins.Breadcrumbs]

  @fields [{:name, :string}, {:born, :integer, required: false}, {:active, :boolean, true: "Yes", false: "No"}]

  defp paths do
    [
      index_path: "/interface",
      new_path: "/interface/new",
      show_path: fn object, _socket -> "/interface/#{object.id}" end,
      edit_path: fn object, _socket -> "/interface/#{object.id}/edit" end
    ]
  end

  defp authors_interface(opts \\ []) do
    {config, opts} = Keyword.pop(opts, :config, [])

    interface(
      Keyword.merge(
        [
          pax_plugins: @plugins,
          pax_config: Keyword.merge([object_name: fn o, _ -> o.name end, fields: @fields] ++ paths(), config),
          count_objects: 1,
          list_objects: [@author],
          new_object: fn _socket -> %Author{} end,
          get_object: fn lookup, criteria, _socket ->
            Owner.notify({:get_object, lookup, criteria})
            @author
          end,
          change_object: fn object, params, _socket -> Author.changeset(object, params) end,
          create_object: fn object, changeset, _socket ->
            Owner.notify({:create_object, object, changeset})
            with {:ok, author} <- Ecto.Changeset.apply_action(changeset, :insert), do: {:ok, %{author | id: 2}}
          end,
          update_object: fn object, changeset, _socket ->
            Owner.notify({:update_object, object, changeset})
            Ecto.Changeset.apply_action(changeset, :update)
          end
        ],
        opts
      )
    )
  end

  describe "show" do
    test "gets the object with the lookup and renders it without a form", %{conn: conn} do
      authors_interface(config: [default_criteria: [where: [active: true]]])

      conn
      |> visit("/interface/1")
      |> assert_has(".pax-show-title", text: "Ursula")
      |> assert_has(".pax-detail-list-field-text", text: "1929")
      |> assert_has(".pax-detail-list-field-text", text: "Yes")
      |> refute_has("form")
      |> assert_has("a.pax-action-edit-button[href='/interface/1/edit']")

      assert_received {:get_object, %{id: "1"}, %{where: [active: true]}}
    end

    test "carries the index_query to the index, show and edit links", %{conn: conn} do
      authors_interface()

      conn
      |> visit("/interface/1?index_query=page%253D2")
      |> assert_has("a.pax-breadcrumbs-link[href='/interface?page=2']")
      |> assert_has("a.pax-action-edit-button[href='/interface/1/edit?index_query=page%253D2']")
      |> click_link("Edit")
      |> assert_path("/interface/1/edit", query_params: %{index_query: "page%3D2"})
      |> assert_has("a.pax-action-edit-cancel-button[href='/interface/1?index_query=page%253D2']")
    end

    test "supports lookup globs", %{conn: conn} do
      authors_interface(config: [lookup_glob: "ids", id_fields: [:org_id, :id]])

      conn
      |> visit("/interface/glob/7/1")
      |> assert_has(".pax-show-title", text: "Ursula")

      assert_received {:get_object, %{org_id: "7", id: "1"}, %{}}
    end
  end

  describe "edit" do
    test "validates and saves the object, then patches to the show page", %{conn: conn} do
      authors_interface()

      conn
      |> visit("/interface/1/edit")
      |> assert_has(".pax-edit-title", text: "Edit: Ursula")
      |> fill_in("Name", with: "")
      |> assert_has(".pax-field-error", text: "can't be blank")
      |> fill_in("Name", with: "Ursula K. Le Guin")
      |> refute_has(".pax-field-error")
      |> fill_in("Born", with: "1930")
      |> click_button("Save")
      |> assert_path("/interface/1")
      |> assert_has("#flash-info", text: "Updated successfully.")

      assert_received {:update_object, @author, %Ecto.Changeset{changes: %{name: "Ursula K. Le Guin", born: 1930}}}
    end

    test "shows errors when saving fails", %{conn: conn} do
      authors_interface()

      conn
      |> visit("/interface/1/edit")
      |> fill_in("Name", with: "")
      |> click_button("Save")
      |> assert_path("/interface/1/edit")
      |> assert_has(".pax-field-error", text: "can't be blank")
      |> refute_has("#flash-info", text: "Updated")
    end

    test "navigates to the index after saving without a show path", %{conn: conn} do
      authors_interface(config: [show_path: nil] |> Keyword.delete(:show_path))

      interface(
        pax_config: [fields: @fields, index_path: "/interface", edit_path: fn o, _ -> "/interface/#{o.id}/edit" end]
      )

      conn
      |> visit("/interface/1/edit")
      |> click_button("Save")
      |> assert_path("/interface")
    end

    test "patches back to the edit page after saving with only an edit path", %{conn: conn} do
      authors_interface()
      interface(pax_config: [fields: @fields, edit_path: fn o, _ -> "/interface/#{o.id}/edit" end])

      conn
      |> visit("/interface/1/edit")
      |> fill_in("Name", with: "Changed")
      |> click_button("Save")
      |> assert_path("/interface/1/edit")
      |> assert_has("#flash-info", text: "Updated successfully.")
    end
  end

  describe "new" do
    test "creates the object, then patches to its show page", %{conn: conn} do
      authors_interface()

      conn
      |> visit("/interface/new?index_query=page%253D2")
      |> assert_has(".pax-new-title", text: "New Object")
      |> assert_has("a.pax-action-edit-cancel-button[href='/interface?page=2']")
      |> fill_in("Name", with: "Octavia")
      |> check("Active")
      |> click_button("Save")
      |> assert_path("/interface/2")
      |> assert_has("#flash-info", text: "Created successfully.")

      assert_received {:create_object, %Author{id: nil}, %Ecto.Changeset{changes: %{name: "Octavia"}}}
    end

    test "shows errors when creating fails", %{conn: conn} do
      authors_interface()

      conn
      |> visit("/interface/new")
      |> click_button("Save")
      |> assert_path("/interface/new")
      |> assert_has(".pax-field-error", text: "can't be blank")
    end
  end

  describe "with an adapter" do
    test "falls back to the adapter for every data operation", %{conn: conn} do
      interface(
        pax_adapter: {FakeAdapter, object: %{id: 1, name: "Ursula"}, new_object: %{id: nil, name: nil}},
        pax_plugins: @plugins,
        pax_config: [fields: [{:name, :string}]] ++ paths()
      )

      conn
      |> visit("/interface/1/edit")
      |> fill_in("Name", with: "Changed")
      |> click_button("Save")
      |> assert_path("/interface/1")

      assert_received {FakeAdapter, :get_object, %{id: "1"}, %{}}
      assert_received {FakeAdapter, :change_object, %{name: "Ursula"}, %{"name" => "Changed"}, [:name]}
      assert_received {FakeAdapter, :update_object, %Ecto.Changeset{changes: %{name: "Changed"}}}

      interface(pax_adapter: {FakeAdapter, new_object: %{id: 5, name: nil}, object: %{id: 5, name: "New"}})

      conn
      |> visit("/interface/new")
      |> fill_in("Name", with: "New")
      |> click_button("Save")
      |> assert_path("/interface/5")

      assert_received {FakeAdapter, :new_object}
      assert_received {FakeAdapter, :create_object, %Ecto.Changeset{changes: %{name: "New"}}}
    end
  end

  # Errors while handling events crash the LiveView process rather than the test, so these call the event handlers
  # directly with a socket prepared the way handle_params leaves it.
  describe "handle_event/3 errors" do
    defp socket(action, opts \\ []) do
      adapter = Keyword.get(opts, :adapter)
      config = Pax.Config.validate!(Pax.Interface.Init.init_config_spec(adapter, []), Keyword.get(opts, :config, []))

      pax = %Pax.Interface{
        module: PaxTest.InterfaceLive,
        adapter: adapter,
        config: config,
        action: action,
        object: %Author{id: 1, name: "Ursula"},
        fields: [Pax.Field.init(nil, {:name, :string})]
      }

      %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}, pax: pax}}
    end

    defp save(socket), do: Detail.handle_event("pax_save", %{"detail" => %{"name" => "Changed"}}, socket)
    defp validate(socket), do: Detail.handle_event("pax_validate", %{"detail" => %{"name" => ""}}, socket)

    test "raise without change_object/3 or an adapter" do
      assert_raise RuntimeError,
                   ~r/You must either define a `change_object\/3` callback, or configure a Pax.Adapter/,
                   fn ->
                     validate(socket(:edit))
                   end
    end

    test "raise when change_object/3 doesn't return a changeset" do
      interface(change_object: fn _, _, _ -> %{} end)

      assert_raise RuntimeError, "change_object/3 must return an Ecto.Changeset, got: %{}", fn ->
        save(socket(:edit))
      end
    end

    test "raise without create_object/3 or update_object/3 or an adapter" do
      interface(change_object: fn object, params, _ -> Author.changeset(object, params) end)

      assert_raise RuntimeError,
                   ~r/You must either define a `create_object\/3` callback, or configure a Pax.Adapter/,
                   fn ->
                     save(socket(:new))
                   end

      assert_raise RuntimeError,
                   ~r/You must either define a `update_object\/3` callback, or configure a Pax.Adapter/,
                   fn ->
                     save(socket(:edit))
                   end
    end

    test "raise when create_object/3 or update_object/3 return something unexpected" do
      interface(
        change_object: fn object, params, _ -> Author.changeset(object, params) end,
        create_object: fn _, _, _ -> :ok end,
        update_object: fn _, _, _ -> {:ok, "not a map"} end
      )

      assert_raise RuntimeError, "create_object/3 must return {:ok, object} or {:error, changeset}, got: :ok", fn ->
        save(socket(:new))
      end

      assert_raise RuntimeError,
                   ~r/update_object\/3 must return {:ok, object} or {:error, changeset}, got: {:ok, "not a map"}/,
                   fn ->
                     save(socket(:edit))
                   end
    end

    test "raise when there's nowhere to go after saving" do
      interface(
        change_object: fn object, params, _ -> Author.changeset(object, params) end,
        update_object: fn _, changeset, _ -> Ecto.Changeset.apply_action(changeset, :update) end
      )

      assert_raise RuntimeError, "Could not determine path to redirect after save", fn -> save(socket(:edit)) end
    end

    test "validation marks the changeset for display" do
      interface(change_object: fn object, params, _ -> Author.changeset(object, params) end)

      assert {:halt, socket} = validate(socket(:edit))
      assert %Phoenix.HTML.Form{source: %Ecto.Changeset{action: :validate}} = socket.assigns.pax.form
    end
  end
end
