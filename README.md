# PhoenixVite

The library …

- provides an igniter.installer to install all the necessary files
  - creates elixir and js boilerplate
  - configures phoenix LV static file tracking with the manifest vite generates
  - uses phoenix static_url configuration to handle all static assets via the vite dev server
  - moves static assets from priv/static to assets/public
- provides a heex function component to pull in js/css from
  - vite dev server in development
  - the vite manifest in prod
- can optionally pull in :bun to run without a locally installed nodejs, just like phoenix does by default

## Installation

### Igniter

```sh
# Fresh project
mix igniter.new my_app --with phx.new --install phoenix_vite [--bun]
# Existing project
mix igniter.install phoenix_vite [--bun]
```

### Manual

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `phoenix_vite` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_vite, "~> 0.2"}
  ]
end
```

```sh
mix phoenix_vite.install [--bun]
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/phoenix_vite>.
