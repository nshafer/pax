# TODO

## General
- [ ] Plugins
- [ ] Make stacktraces better?

## Index
- [ ] Pagination plugin
- [ ] Sorting plugin
- [ ] Filters plugin
- [ ] Actions plugin
- [ ] Maybe refactor fieldsets to use css grid?
- [ ] Field alignment: left, center, right
- [ ] Action Items plugin
- [ ] Sidebar plugin
- [ ] More index types: table, grid, blocks, blog? (ActiveAdmin)

## Detail
- [ ] :edit
- [ ] :new
- [ ] :delete or DeleteLive module?
- [ ] Inline plugin
- [ ] Audit log plugin with revert?
- [ ] Collab / presence plugin
- [ ] Action Items plugin

## Fields
- [x] Allow specifying just `:fieldname` and default to Field.String maybe? Or callback to adapter to figure it out?

## Admin
- [x] `use Pax.Admin` macros to create base admin Index/Detail modules with all settings
    - [x] `section :name, "Title" do` to create sections of resources.
    - [x] `resource :users, "Users", UserAdmin` to list all admins to include
    - [ ] `link :name, ~p"/somewhere/"` for random links
- [x] `pax_admin "/admin", MyAppWeb.Admin` macro for route injection
- [ ] Admin interface with sidebar menu
- [ ] Flashes
- [ ] Dashboard with widgets
- [ ] Create `resources MyAppWeb.MyAdmin do` macro, which gets prefixed before resources modules, so can do `resource :name, "Title", LabelResource` to save typing. Same as Phoenix router scopes.
- [ ] Bookmarks - save current params as custom link in nav bar.
- [ ] Allow configuration of sites, resources, etc with macros instead of run-time callbacks.

## Static
- [ ] Fix/figure out phx.digest. Do it or not? (Probably not...)
    - [ ] Figure out / write docs on importing pax.css directly.
    - [ ] Figure out / write docs on creating custom admin.css that imports pax_admin.css
- [ ] Rejig `mix assets.deploy` to output to pax.min.css
- [x] Make basic pax.css using minimal css instead of tailwind?
- [ ] Maybe don't use tailwind for pax.css? Use postcss instead?
