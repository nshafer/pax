# Pax

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pax` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pax, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/pax>.

## CSS and JS

Two modes:

1. Configure your project's tailwind to scan the pax dep for used classes
2. Configure a Plug.Static in your endpoint to load static files from the :pax app, then include the pax statics in your
   html.
