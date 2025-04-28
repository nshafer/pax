# This is duplicated here from pax's formatter.exs due to not being able to define `:pax` as
# a dependency in the `import_deps` list, since it is local to this mono repo.
locals_without_parens = [
  # Pax.Admin.Router macros
  pax_admin: 2,
  pax_admin: 3,

  # Pax.Admin.Site macros
  config: 1,
  section: 2,
  section: 3,
  resource: 2,
  resource: 3,
  resource: 4,
  link: 2,
  link: 3,
  link: 4,
  page: 2,
  page: 3,
  page: 4
]

[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"],
  locals_without_parens: locals_without_parens
]
