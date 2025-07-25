# TODO

## General
- [x] Plugins
- [ ] Make stacktraces better? Examples:
      - https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/query/builder.ex#L1447
      - https://github.com/phoenixframework/phoenix_live_view/blob/v1.0.5/lib/phoenix_live_view/engine.ex#L1129-L1158
- [ ] Reimplement mobile views as @container queries
- [x] Redo callback hell to instead just use one `pax_config` callback that sets a global config that is stored in the
      `@pax` context. This should have all config options, including any extra config for the adapters or plugins.
- [x] Reimplement main index table and detail view as individual plugins.
- [x] Upgrade to LiveView 1.0 - transition away from `phx-feedback-for`
- [x] Redo Adapter `get_object` to use the scope. Should we formally define the scope with a struct or not?
- [ ] Make adapter optional so all needed callbacks can be specified in the LV, falling back to adapter, then erroring.
- [ ] Allow override or modification of EctoSchema queries before executing.
- [ ] Authorization system, such as `can_view`, `can_edit`, `can_delete` or whatever.
- [ ] Tests!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
- [ ] Convert all MF callbacks to MFA with docs that certain args are prepended to the list. See
      [:check_origin](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-common-configuration).

## Interface
- [ ] Create `pax_interface` macro in `Pax.Router` module that defines the routes for a `Pax.Interface`, with keys like
      the `resources` macro in Phoenix.
- [x] Namespace config, so that adapter and plugin configs are explicit, such as:
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
- [x] Stream objects
- [x] Fix breadcrumbs when no `index_path` or nil `object_name` given.
- [ ] Returnable `%URL{}` structs from `*_path` config options?

### Index
- [x] Pagination plugin
- [x] Convert table to plugin
- [ ] Sorting plugin
- [ ] Filters plugin
- [ ] Actions plugin
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
- [ ] Maybe refactor fieldsets to use css grid?
- [ ] Action Items plugin
- [ ] Handle unique violations better. (Duplicate: use duplicate slug or something)
- [x] Crash when id field(s) changed
- [ ] Crash with foreign_key_constraint violation when field that is a foreign_key on other table is changed. e.g.
      change author_id.
  [ ] If changeset has an error for a field not visible, no errors are shown. Should show it still somewhere.

## Fields
- [x] Allow specifying just `:fieldname` and default to Field.String maybe? Or callback to adapter to figure it out?
- [x] Redo fields to just have one list of fields, with `only: :index` and `except: [:index, :edit]` options.
- [ ] Check for duplicate field definitions, or fix ids? (duplicate id warnings in console if field is specified twice)
- [x] Redo fieldsets to just be `detail_layout` to specify how the fields are laid out. Defaults to just the list
      of fields. Any missing fields are assumed to not be included. Should we allow `show_layout` and `edit_layout`
      specific layouts? So the pages can have different layouts? (no for now.)

## Admin
- [x] `use Pax.Admin` macros to create base admin Index/Detail modules with all settings
    - [x] `section :name, "Label" do` to create sections of resources.
    - [x] `resource :users, "Users", UserAdmin` to list all admins to include
    - [ ] `link :name, ~p"/somewhere/"` for random links
- [x] `pax_admin "/admin", MyAppWeb.Admin` macro for route injection
- [x] Admin interface with sidebar menu
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
- [ ] Create single entry point Plug for all Pax related paths. Mainly static for now.
- [ ] Create system for plugin static files to be accessible without extra config by user.
- [ ] Fix/figure out phx.digest. Do it or not? (Probably not...)
    - [ ] Figure out / write docs on importing pax.css directly.
    - [ ] Figure out / write docs on creating custom admin.css that imports pax_admin.css
- [ ] Rejig `mix assets.deploy` to output to pax.min.css
- [x] Make basic pax.css using minimal css instead of tailwind?
- [x] Maybe don't use tailwind for pax.css? Use ~~postcss~~ sass instead?

## Rename?
- pax - peace, pax romana, PAX conference, etc. Very overloaded.
- ~~kite~~ taken on hex
- jib
- pixy
- pyx - A pyx or pix is a small round container used in Catholic churches to carry the Eucharist
