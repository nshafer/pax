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
  import_deps: [:ecto, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,dev,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["sandbox"],
  line_length: 120,
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
