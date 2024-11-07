# Pax

**DO NOT USE THIS MODULE... YET**

This module is under heavy development, and is not ready for anyone to use it yet.

Pax (Phoenix Admin eXtensions) is a toolkit for adding CRUD functionality to LiveViews, as well as
an admin interface built on those tools.

## Installation

Rough instructions for now.

Add `pax` to your list of dependencies in "mix.exs":

```elixir
def deps do
  [
    {:pax, "~> 0.1.0"}
  ]
end
```

Add a `Plug.Static` plug to load static assets at /pax directly from the pax dependency. Add the
following to your "lib/myapp_web/endpoint.ex", after any `socket` lines, and before
`plug Plug.Parsers`. The best place is right after any existing `plug Plug.Static` lines.

```elixir
plug Plug.Static,
  at: "/pax",
  from: :pax,
  gzip: false
```


