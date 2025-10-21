# Pax Plugins

Some functionality in Pax is provided by Plugins. This is for extra functionality built on to the base functionality
of Index, Detail pages, Admin interface, etc.

## Types of plugins

### Interface plugins

These add functionality to the main Index and Detail interfaces.

`Pax.Interface.Plugin`

Index Examples:

- Pagination - `Pax.Plugins.Pagination` - does limit/offset style
- Sorting - `Pax.Plugins.Sorting`
- Actions - `Pax.Plugins.Actions`
- Filters - `Pax.Plugins.Filters`
- Search - `Pax.Plugins.Search`

Detail Examples:

- Metadata - `Pax.Plugins.Metadata`
- Collab / presence `Pax.Plugins.Collab`
- Audit log - `Pax.Plugins.AuditLog`

### Admin plugins

These add functionality to the Pax.Admin interface that wraps the inner Pax.Interface interface.

`Pax.Admin.Plugin`

Examples:

- Breadcrumbs - `Pax.Admin.Plugins.Breadcrumbs`
- Sidebar menu - `Pax.Admin.Plugins.SidebarMenu`
- Theme switch - `Pax.Admin.Plugins.ThemeSwitcher`
- Favorites / Bookmarks - `Pax.Admin.Plugins.Bookmarks`

### Adapter plugins

Each adapter could create a plugin interface.

## Plugin behaviour

There are a few behaviours for Plugins:

- `Pax.Plugin` - The main behaviour for any plugin to be included in the `plugins` list. Mainly just
    a `type/0` and an `init/1` callback.
- `Pax.Interface.Plugin` - Plugins that work with the main Interface (Index, Detail (Show, Edit), Delete).
- `Pax.Admin.Plugin` - Plugins that work with the Admin interface specifically.

Each behaviour defines callbacks and default implementations that return nil by default. The list of plugins is defined
by the user, and on init each plugin's init is called with any options given by the user, and the returned map is stored
in the `:pax` map in the assigns. Then everywhere that interfaces with plugins will just call the proper callback, and
if the return is not nil, do something with the answer.

### Component callbacks

There are special callbacks that are Phoenix.Components. They will be defined like usual, but there the `opts` for the
plugin will be included in the assigns passed to them. An example for the tools sections, which are areas in the
interface that allow the insertion of miscellaneous "tools" in the admin header, interface header, or interface footer:

```html
    <.pax_header>
        <:primary>
            Title
            <%= plugin_component(:index_header_primary, assigns) %>
        </:primary>
        <:secondary>
            <.pax_button>...</.pax_button>
            <%= plugin_component(:index_header_secondary, assigns) %>
        </:secondary>
    </.pax_header>
```

Then any plugin that wants to insert something into this area of the interface just defines the proper component:

```elixir
attr :pax, Pax.Interface, required: true
attr :opts, :map, required: true

def index_header_secondary(assigns) do
  ~H"""
    <.pax_button>...</.pax_button>
  """
end
