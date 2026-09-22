# PhoenixVite

PhoenixVite integrates Vite build tooling with Phoenix.

[![Upstream build](https://github.com/LostKobrakai/phoenix_vite/actions/workflows/elixir.yml/badge.svg?branch=main)](https://github.com/LostKobrakai/phoenix_vite/actions/workflows/elixir.yml)
[![Hex release](https://img.shields.io/hexpm/v/phoenix_vite.svg?label=release)](https://hex.pm/packages/phoenix_vite)
[![Hex downloads](https://img.shields.io/hexpm/dt/phoenix_vite.svg)](https://hex.pm/packages/phoenix_vite)
[![Hex license](https://img.shields.io/hexpm/l/phoenix_vite.svg)](LICENSE)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/phoenix_vite)

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
    {:phoenix_vite, "~> 0.6.0"}
  ]
end
```

```sh
mix phoenix_vite.install [--bun]
```

Documentation is available on [HexDocs](https://hexdocs.pm/phoenix_vite).

## Development

### Requirements

- Elixir `~> 1.18`
- Node.js `^20.19.0` or `>=22.12.0`, as required by Vite 7

The upstream CI currently tests Elixir 1.18 with Erlang/OTP 26 and Elixir 1.20 with Erlang/OTP 29. The Nix development shell uses the locally verified intermediate line: Elixir 1.19, Erlang/OTP 28, and Node.js 24.

Install these requirements manually, or use the repository Nix Flake.

<details>
<summary>Install Nix and direnv</summary>

- [Install Nix](https://nixos.org/download/)
- [Enable Nix flakes](https://nix.dev/concepts/flakes)
- [Install direnv](https://direnv.net/docs/installation.html)
- [Configure the direnv shell hook](https://direnv.net/docs/hook.html)
- Optionally install [nix-direnv](https://github.com/nix-community/nix-direnv)

</details>

<br>

Enter the environment manually:

```sh
nix develop
```

Or authorize automatic loading once:

```sh
direnv allow
```

Local development variables can be placed in `envs/.env`; use `envs/.env.example` as the template. No variables are required by default. The Nix shell keeps Mix and Hex state under `.nix/` so archives compiled for another BEAM version cannot leak into this environment.

Install project dependencies and the test fixture generator after entering the environment:

```sh
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.8.9 --force
mix deps.get --check-locked
npm ci
```

### Commands

| Command | Purpose |
| --- | --- |
| `mix test` | Run the Elixir test suite |
| `mix checks` | Run formatting, compilation, dependency, and Dialyzer checks |
| `npm run build` | Compile the TypeScript package |

### Stack

| Area | Version source |
| --- | --- |
| Development environment | [`flake.nix`](flake.nix) |
| Elixir package and dependencies | [`mix.exs`](mix.exs) |
| Node.js package and frontend tooling | [`package.json`](package.json) |

## License

Licensed under the [Apache License 2.0](LICENSE).
