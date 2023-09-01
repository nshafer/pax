# TODO

## General
- [ ] Plugins
- [ ] Rename Index to List?
- [ ] Make stacktraces better?

## Index
- [ ] Pagination plugin
- [ ] Sorting plugin
- [ ] Filters plugin
- [ ] Actions plugin
- [ ] Maybe refactor fieldsets to use css grid?
- [ ] Field alignment: left, center, right

## Detail
- [ ] Inline plugin
- [ ] Audit log plugin
- [ ] Collab / presence plugin

## Fields
- [ ] Allow specifying just `:fieldname` and default to Field.String maybe? Or callback to adapter to figure it out?

## Admin
- [x] `use Pax.Admin` macros to create base admin Index/Detail modules with all settings
    - [x] `section :name, "Title" do` to create sections of resources.
    - [x] `resource :users, "Users", UserAdmin` to list all admins to include
    - [ ] `link :name, ~p"/somewhere/"` for random links
- [x] `pax_admin "/admin", MyAppWeb.Admin` macro for route injection
- [ ] Admin interface with sidebar menu
- [ ] Flashes
- [ ] Dashboard with widgets
- [ ] Support section prefixes in macro, i.e. `section :name, "Title", PaxDemoWeb.Admin do/end` which gets prefixed onto resources, so can do `resource :name, "Title", LabelResource` to save typing. Same as Phoenix router scopes.
- [ ] Recents - save current params as recent view, allow pinning.

## Static
- [ ] Fix/figure out phx.digest. Do it or not? (Probably not...)
    - [ ] Figure out / write docs on importing pax.css directly.
    - [ ] Figure out / write docs on creating custom admin.css that imports pax_admin.css
- [ ] Rejig `mix assets.deploy` to output to pax.min.css
- [x] Make basic pax.css using minimal css instead of tailwind?
- [ ] Maybe don't use tailwind for pax.css? Use postcss instead?
