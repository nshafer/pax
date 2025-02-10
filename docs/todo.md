# TODO

## General
- [x] Plugins
- [ ] Make stacktraces better? https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/query/builder.ex#L1447
- [ ] Reimplement mobile views as @container queries
- [x] Redo callback hell to instead just use one `pax_config` callback that sets a global config that is stored in the
      `@pax` context. This should have all config options, including any extra config for the adapters or plugins.
- [ ] Reimplement main index table and detail view as individual plugins.
- [x] Upgrade to LiveView 1.0 - transition away from `phx-feedback-for`
- [x] Redo Adapter `get_object` to use the scope. Should we formally define the scope with a struct or not?
- [ ] Allow override or modification of EctoSchema queries before executing.
- [ ] Permissions system, such as `can_view`, `can_edit`, `can_delete` or whatever.
- [ ] Tests!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

## Interface
- [ ] Create `pax_interface` macro in `Pax.Router` module that defines the routes for a `Pax.Interface`, with keys like
      the `resources` macro in Phoenix, such as `only: [:index, :show]` and `except: [:edit, :delete]`.
- [ ] Namespace config, so that adapter and plugin configs are explicit, such as:
      ```elixir
      [
        adapter: [
            repo: Myapp.Repo,
            schema: Myapp.Mycontext.Myschema
        ],
        plugins: [
            pagination: [
                objects_per_page: 100
            ]
        ]
      ]
- [ ] Stream objects
- [ ] Fix breadcrumbs when no `index_path` or nil `object_name` given.
- [ ] Returnable `%URL{}` structs from `*_path` config options?

### Index
- [x] Pagination plugin
- [ ] Convert table to plugin
- [ ] Sorting plugin
- [ ] Filters plugin
- [ ] Actions plugin
- [ ] Maybe refactor fieldsets to use css grid?
- [ ] Field alignment: left, center, right
- [ ] Action Items plugin
- [ ] More index types: table, grid, blocks, blog? (ActiveAdmin)

### Detail
- [x] :edit
- [x] :new
- [ ] :delete or DeleteLive module?
- [ ] Inline plugin
- [ ] Audit log plugin with revert?
- [ ] Collab / presence plugin
- [ ] Action Items plugin
- [ ] Handle unique violations better. (Duplicate: use duplicate slug or something)

## Fields
- [x] Allow specifying just `:fieldname` and default to Field.String maybe? Or callback to adapter to figure it out?
- [ ] Redo fields to just have one list of fields, with `only: :index` and `except: [:index, :edit]` options.
- [ ] Redo fieldsets to just be `detail_layout` to specify how the fields are laid out. Defaults to just the list
      of fields. Any missing fields are assumed to not be included. Should we allow `show_layout` and `edit_layout`
      specific layouts? So the pages can have different layouts?

## Admin
- [x] `use Pax.Admin` macros to create base admin Index/Detail modules with all settings
    - [x] `section :name, "Label" do` to create sections of resources.
    - [x] `resource :users, "Users", UserAdmin` to list all admins to include
    - [ ] `link :name, ~p"/somewhere/"` for random links
- [x] `pax_admin "/admin", MyAppWeb.Admin` macro for route injection
- [x] Admin interface with sidebar menu
- [ ] Make dark-mode plus-only?
- [ ] Flashes
- [ ] Dashboard with widgets.
- [ ] Section dashboards with default just list of resources contained within.
- [ ] Create `resources MyAppWeb.MyAdmin do` macro, which gets prefixed before resources modules, so can do
      `resource :name, "Label", LabelResource` to save typing. Same as Phoenix router scopes. Investigate LSP hooks?
- [ ] Bookmarks - save current params as custom link in nav bar.
- [ ] Allow configuration of sites, resources, etc with macros instead of run-time callbacks.
- [ ] Sidebar plugin with collapse
- [ ] Sidebar menu icons for resources, default to squares with first letter. Section arrow instead of icon.

## Static
- [ ] Fix/figure out phx.digest. Do it or not? (Probably not...)
    - [ ] Figure out / write docs on importing pax.css directly.
    - [ ] Figure out / write docs on creating custom admin.css that imports pax_admin.css
- [ ] Rejig `mix assets.deploy` to output to pax.min.css
- [x] Make basic pax.css using minimal css instead of tailwind?
- [x] Maybe don't use tailwind for pax.css? Use ~~postcss~~ sass instead?

## Rename?
- ~~kite~~ taken on hex
- jib
- pixy
