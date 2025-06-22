if Code.ensure_loaded?(Igniter) do
  defmodule PhoenixVite.Igniter do
    @moduledoc false

    @doc """
    Create a minimal vite config at `assets/vite.config.mjs`
    """
    def create_vite_config(igniter) do
      Igniter.create_new_file(igniter, "assets/vite.config.mjs", """
      import { defineConfig } from 'vite'
      import tailwindcss from "@tailwindcss/vite";

      export default defineConfig({
        server: {
          port: 5173,
          strictPort: true,
          cors: { origin: "http://localhost:4000" },
        },
        build: {
          manifest: true,
          rollupOptions: {
            input: ["js/app.js", "css/app.css"],
          },
          outDir: "../priv/static",
          emptyOutDir: true,
        },
        plugins: [tailwindcss()]
      });
      """)
    end

    @doc """
    Updates dev.exs up with endpoints static_url configuration pointing to vite dev server.
    """
    def configure_dev_server_static_url_for_development(igniter, app_name, endpoint) do
      Igniter.Project.Config.configure(igniter, "dev.exs", app_name, [endpoint, :static_url],
        host: "localhost",
        port: 5173
      )
    end

    @doc """
    Disable phoenix cache_static_manifest in favor of using vites manifest.
    """
    def use_only_vite_assets_caching(igniter, app_name, endpoint) do
      igniter
      |> Igniter.Project.Config.configure("prod.exs", app_name, [endpoint], [],
        updater: fn zipper ->
          with :error <- Igniter.Code.Keyword.remove_keyword_key(zipper, :cache_static_manifest) do
            {:ok, zipper}
          end
        end
      )
      |> Igniter.Project.Config.configure_runtime_env(
        :prod,
        app_name,
        [endpoint, :cache_static_manifest_latest],
        {:code,
         Sourceror.parse_string!("PhoenixVite.cache_static_manifest_latest(#{inspect(app_name)})")}
      )
    end

    @doc """
    Add module preload polyfill to JS.

    See https://vite.dev/guide/backend-integration.html
    """
    def add_module_preload_polyfill(igniter) do
      Igniter.update_file(igniter, "assets/js/app.js", fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          ~s|import "vite/modulepreload-polyfill";\n| <> content
        end)
      end)
    end

    @doc """
    Move all static files to `assets/public` to be handles by vite.
    """
    def use_vite_public_folder_for_static_assets(igniter) do
      igniter
      |> Igniter.mkdir("assets/public")
      |> Igniter.include_glob("priv/static/**/*")
      |> then(fn igniter ->
        Enum.reduce(igniter.rewrite.sources, igniter, fn {path, _}, igniter ->
          case Path.split(path) do
            ["priv", "static", "assets" | _] ->
              igniter

            ["priv", "static" | rest] ->
              Igniter.move_file(igniter, path, Path.join(["assets", "public" | rest]))

            _ ->
              igniter
          end
        end)
      end)
      |> Igniter.update_file(".gitignore", fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          String.replace(
            content,
            """
            /priv/static/assets/

            # Ignore digested assets cache.
            /priv/static/cache_manifest.json
            """,
            """
            /priv/static/*
            """
          )
        end)
      end)
    end

    @doc """
    Replace static assets relations in root layout with dynamic vite ones.
    """
    def link_root_layout_to_vite(igniter, app_name, endpoint, web_module) do
      web_folder = Macro.underscore(web_module)
      root_layout = Path.join(["lib", web_folder, "components/layouts/root.html.heex"])

      Igniter.update_file(igniter, root_layout, fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          String.replace(
            content,
            """
                <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
                <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
                </script>
            """,
            """
                <PhoenixVite.Components.assets
                  names={["js/app.js", "css/app.css"]}
                  manifest={{#{inspect(app_name)}, "priv/static/.vite/manifest.js"}}
                  dev_server={PhoenixVite.Components.has_vite_watcher?(#{inspect(endpoint)})}
                  to_url={fn p -> static_url(@conn, p) end}
                />
            """
          )
        end)
      end)
    end

    @doc """
    Adjust phoenix `assets.*` tasks.
    """
    def adjust_assets_task_definitions(igniter) do
      igniter
      |> Igniter.Project.TaskAliases.modify_existing_alias("assets.setup", fn zipper ->
        alias = Sourceror.parse_string!(~s|["bun.install --if-missing", "bun assets install"]|)
        {:ok, Igniter.Code.Common.replace_code(zipper, alias)}
      end)
      |> Igniter.Project.TaskAliases.modify_existing_alias("assets.build", fn zipper ->
        alias = Sourceror.parse_string!(~s|["bun vite build"]|)
        {:ok, Igniter.Code.Common.replace_code(zipper, alias)}
      end)
      |> Igniter.Project.TaskAliases.modify_existing_alias("assets.deploy", fn zipper ->
        alias = Sourceror.parse_string!(~s|["assets.build"]|)
        {:ok, Igniter.Code.Common.replace_code(zipper, alias)}
      end)
    end

    @doc """
    Remove esbuild and tailwind applications and integrations
    """
    def remove_default_assets_handling(igniter, app_name, endpoint) do
      alias Igniter.Code.Function

      Enum.reduce([:esbuild, :tailwind], igniter, fn dependency, igniter ->
        igniter =
          if endpoint do
            path = [endpoint, :watchers]

            Igniter.Project.Config.configure(igniter, "dev.exs", app_name, path, [],
              updater: fn zipper ->
                with :error <- Igniter.Code.Keyword.remove_keyword_key(zipper, dependency) do
                  {:ok, zipper}
                end
              end
            )
          else
            igniter
          end

        igniter
        |> Igniter.update_elixir_file("config/config.exs", fn zipper ->
          predicate = &Function.argument_equals?(&1, 0, dependency)

          zipper
          |> Function.move_to_function_call_in_current_scope(:config, [2, 3], predicate)
          |> case do
            :error -> {:ok, zipper}
            {:ok, zipper} -> Sourceror.Zipper.remove(zipper)
          end
        end)
        |> Igniter.Project.Deps.remove_dep(dependency)
        |> Igniter.add_task("deps.clean", ["--unlock", "--unused", "#{dependency}"])
      end)
    end

    @doc """
    Add :bun dependency to project integrated with vite
    """
    def add_bun(igniter, app_name, endpoint) do
      igniter
      |> Igniter.Project.Deps.add_dep(
        {:bun, "~> 1.4",
         runtime: quote(do: Mix.env() == :dev),
         github: "LostKobrakai/elixir_bun",
         branch: "LostKobrakai-patch-1",
         override: true},
        append?: true
      )
      |> Igniter.create_new_file("assets/package.json", """
      {
        "workspaces": [
          "../deps/*"
        ],
        "dependencies": {
          "phoenix": "workspace:*",
          "phoenix_html": "workspace:*",
          "phoenix_live_view": "workspace:*",
          "topbar": "^3.0.0"
        },
        "devDependencies": {
          "tailwindcss": "^4.1.0",
          "daisyui": "^5.0.0",
          "@tailwindcss/vite": "^4.1.0",
          "vite": "^6.3.0"
        }
      }
      """)
      |> Igniter.update_file("assets/js/app.js", fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          String.replace(content, "../vendor/topbar", "topbar")
        end)
      end)
      |> Igniter.update_file("assets/css/app.css", fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          content
          |> String.replace("../vendor/daisyui-theme", "daisyui/theme")
          |> String.replace("../vendor/daisyui", "daisyui")
        end)
      end)
      |> Igniter.rm("assets/vendor/topbar.js")
      |> Igniter.rm("assets/vendor/daisyui.js")
      |> Igniter.rm("assets/vendor/daisyui-theme.js")
      |> Igniter.Project.Config.configure("config.exs", :bun, [:version], "1.2.16")
      |> Igniter.Project.Config.configure(
        "config.exs",
        :bun,
        [:assets],
        {:code, Sourceror.parse_string!(~s|[args: [], cd: Path.expand("../assets", __DIR__)]|)}
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :bun,
        [:vite],
        {:code,
         Sourceror.parse_string!(~s|[args: ~w(x vite), cd: Path.expand("../assets", __DIR__)]|)}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [endpoint, :watchers, :vite],
        {:code, Sourceror.parse_string!(~s|{Bun, :install_and_run, [:vite, ~w(dev)]}|)}
      )
      |> Igniter.add_task("deps.get")
      |> Igniter.add_task("assets.setup")
    end
  end
end
