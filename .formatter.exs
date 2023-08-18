locals_without_parens = [
  adapter: 1,
  adapter: 2,
  pax_admin: 2,
  pax_admin: 3,
  config: 1,
  section: 3,
  resource: 3,
  resource: 4
]

[
  import_deps: [:ecto, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"],
  line_length: 120,
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
