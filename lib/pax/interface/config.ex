defmodule Pax.Interface.Config do
  @moduledoc """
  Configuration for a Pax Interface.

  This module defines the configuration spec for a Pax.Interface module.

  ## Configuration

  The following configuration keys are supported:

  ### `singular_name`

  The singular name of the object. e.g. "User". Used in places such as the "New User" button.

  If not given, will introspect from the Adapter.

  Valid values:
  * `string` - A string value.
  * `function` - A function that takes the socket and returns a string.

  ### `plural_name`

  The plural name of the object. e.g. "Users". Used in places such as the index page title, breadcrumbs, etc.

  If not given, will introspect from the Adapter.

  Valid values:
  * `string` - A string value.
  * `function` - A function that takes the socket and returns a string.

  ### `object_name`

  The name of a specific object. e.g. "User 123" or "John Doe".

  If not given, will introspect from the Adapter.

  Valid values:
  * `string` - A string value.
  * `function` - A function that takes the object and the socket and returns a string. If the function returns `nil`,
    then the object name will be introspected from the Adapter.

  ### `index_path`

  The path to the index action, as defined in your router, so if you have a route like:

      live "/users", UserLive, :index

  Then the `index_path` would be `"/users"`.

  If not given, no links will be generated to the index page.

  Valid values:
  * `string` - A string path.
  * `function` - A function that takes the socket and returns a string.

  ### `new_path`

  The path to the new action, as defined in your router, so if you have a route like:

      live "/users/new", UserLive, :new

  Then the `new_path` would be `"/users/new"`.

  If not given, then the "New User" button will not be displayed.

  Valid values:
  * `string` - A string path.
  * `function` - A function that takes the socket and returns a string.

  ### `show_path`

  The path to the show page, as defined in your router, so if you have a route like:

      live "/users/:id", UserLive, :show

  Then the `show_path` function would return a string such as `"/users/\#{object.id}"`.

  If this is given, then all `link: true` fields will use this URL to link to the show page. If no fields have
  `link: true`, then the first field will be linked if this is set.

  If this is not given, then links will use the `edit_path` if defined, or no links will be generated.

  Tip: Set this and not the `edit_path` if you want to have a read-only interface, where links only go to the show page,
  and no edit page is available.

  Valid values:
  * `function` - A function that takes the object and the socket and returns a string.

  ### `edit_path`

  The path to the edit page, as defined in your router, so if you have a route like:

      live "/users/:id/edit", UserLive, :edit

  Then the `edit_path` function would return a string such as `"/users/\#{object.id}/edit"`.

  If this is given, then the "Edit" button will link to this URL.

  If this is given and `show_path` is not, then all `link: true` fields will use this URL to link to the edit page.

  If this, nor the `show_path` are given, then no links will be generated.

  Tip: Set this and not the `show_path` if you want to have a traditional Admin interface, where the index page links
  straight to the edit page of each object.

  Valid values:
  * `function` - A function that takes the object and the socket and returns a string.

  ### `index_fields`

  The fields to display in the index page. This should be a list of field specs.

  Please see `Pax.Field` for more information.

  Valid values:
  * `list` - A list of field specs.
  * `function` - A function that takes the socket and returns a list of field specs.

  ### `fieldsets`

  The fieldsets to display in the detail page. This should be either a list of fieldset specs, or a keyword list of
  sections with a list of fieldset specs.

  Please see `Pax.Field` for more information.

  Valid values:
  * `list` - A list of fieldset specs.
  * `function` - A function that takes the socket and returns a list of fieldset specs.

  ### `lookup`

  A function that returns a map of lookup keys to values, which is passed directly to the Adapter's `get_object`
  function. This is useful for customizing how the object is looked up for detail pages (show, edit, delete).

  This supersedes the `lookup_params`, `lookup_glob` and `id_fields` options.

  Valid values:
  * `function` - A function that takes the object, the params, and the socket and returns a map.

  ### `lookup_params`

  A list of param keys to use when automatically building the lookup map. This should be a list of strings that
  correspond to the placeholder segments in your router for the detail actions. So if you have a route like:

      live "/users/:id", UserLive, :show

  Then the `lookup_params` would be `["id"]`.

  You can specify multiple params if your route has multiple placeholders that correspond to multiple `id_fields`, such
  as if your object has a composite primary key. For example:

      live "/users/:org_id/:user_id", UserLive, :show

  Then the `lookup_params` would be `["org_id", "user_id"]`.

  The number of params must match the number of `id_fields` exactly, as in the end they are just zipped together to
  form the lookup map, which is passed directly to the Adapter.

  Valid values:
  * `list` - A list of param names as strings.
  * `function` - A function that takes the socket and returns a list of param names as strings.

  ### `lookup_glob`

  Instead of defining a set number of `lookup_params`, you can define a glob to use to get the object. This is useful
  when you want to match a variable number of params in your router, to a specific number of `id_fields`. For example:

      live "/users/*ids", UserLive, :show

  Then the `lookup_glob` would be `"ids"`, where you could then match a URL like:

      /users/123/456

  and then the `id_fields` would be `[:org_id, :id]`, for example.

  This is of dubious use when you know the exact number of `id_fields` you have, but is how the Pax.Admin can handle
  arbitrary numbers of `id_fields` for composite primary keys with only one defined route.

  Valid values:
  * `string` - A string value.
  * `function` - A function that takes the socket and returns a string.

  ### `id_fields`

  The fields of an object that are used to uniquely identify it. This is used to build the lookup map for the detail
  pages (show, edit, delete). This should be a list of field names as atoms.

  The number of `id_fields` must match the number of `lookup_params` exactly, or the number of params matched by
  a `lookup_glob`, as in the end they are just zipped together to form the lookup map, which is passed directly to the
  Adapter.

  Valid values:
  * `list` - A list of field names as atoms.
  * `function` - A function that takes the socket and returns a list of field names as atoms.

  ## Example

  ```elixir
  def pax_config(_socket) do
    [
      repo: Myapp.Repo,
      schema: Myapp.Library.Book,
      singular_name: "Book",
      plural_name: "Books",
      object_name: fn object, _socket -> object.title end,
      index_path: ~p"/books",
      new_path: ~p"/books/new",
      show_path: fn object, _socket -> ~p"/books/\#{object.id}/\#{object.slug}" end,
      edit_path: fn object, _socket -> ~p"/books/\#{object.id}/\#{object.slug}/edit" end,
      lookup_params: ["id", "slug"],
      id_fields: [:id, :slug],
      index_fields: [
        {:title, link: true},
        :rank,
        :downloads,
        :reading_level,
        :publication_date
      ],
      fieldsets: [
        default: [
          [:title, :slug],
          [:rank, :downloads],
          [:reading_level, :words],
          [:author_id, :language_id],
          :visible
        ],
        metadata: [
          :pg_id,
          :publication_date,
          [:inserted_at, :updated_at]
        ],
        statistics: [
          [:rank, :downloads],
          [:reading_level, :words]
        ]
      ]
    ]
  end
  ```

  """

  def config_spec() do
    %{
      singular_name: [:string, {:function, 1, :string}],
      plural_name: [:string, {:function, 1, :string}],
      object_name: [:string, {:function, 2, [nil, :string]}],
      index_path: [:string, {:function, 1, :string}],
      new_path: [:string, {:function, 1, :string}],
      show_path: {:function, 2, :string},
      edit_path: {:function, 2, :string},
      index_fields: [:list, {:function, 1, :list}],
      fieldsets: [:list, {:function, 1, :list}],
      lookup: {:function, 3, :map},
      lookup_params: [:list, {:function, 1, :list}],
      lookup_glob: [:string, {:function, 1, :string}],
      id_fields: [:list, {:function, 1, :list}]
    }
  end

  def default_lookup_params(), do: ["id"]

  def default_id_fields, do: [:id]
end
