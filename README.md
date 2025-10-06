# Pax

**DO NOT USE THIS MODULE... YET**

This module is under heavy development, and is not ready for anyone to use it yet.

Pax (Phoenix Admin eXtensions) is a toolkit for adding CRUD functionality to LiveViews, as well as
an admin interface built on those tools.

## Installation

Rough instructions for now.

### Dependency

Add `pax` to your list of dependencies in "mix.exs":

```elixir
def deps do
  [
    {:pax, "~> 0.1.0"}
  ]
end
```

### Static assets

Add the following to your "lib/myapp_web/endpoint.ex", after any `socket` lines, and before
`plug Plug.Parsers`. The best place is right after any existing `plug Plug.Static` lines.

```elixir
plug Pax.Assets
```

Add the pax static assets to "myapp_web/components/root.html.heex", in the `<head>`, and before your own css and js
so you can easily override the pax css.

This only gives a bare-minimum of styling and functionality that is designed to be a good starting point for your own
customizations.

This is only needed if you're using `Pax.Interface` directly, and not needed if you are only using `Pax.Admin`.

```html
<head>
  ...
  <Pax.Components.assets />
  ...
</head>
```

