if Code.ensure_loaded?(Igniter) do
  defmodule PhoenixVite.Igniter do
    @moduledoc false
    alias Sourceror.Zipper

    @doc """
    Create a minimal vite config at `assets/vite.config.mjs`
    """
    def create_vite_config(igniter) do
      Igniter.create_new_file(igniter, "assets/vite.config.mjs", """
      import { defineConfig } from 'vite'
      import { phoenixVitePlugin } from 'phoenix_vite'
      import tailwindcss from "@tailwindcss/vite";

      export default defineConfig({
        server: {
          port: 5173,
          strictPort: true,
          cors: { origin: "http://localhost:4000" },
        },
        optimizeDeps: {
          // https://vitejs.dev/guide/dep-pre-bundling#monorepos-and-linked-dependencies
          include: ["phoenix", "phoenix_html", "phoenix_live_view"],
        },
        build: {
          manifest: true,
          rollupOptions: {
            input: ["js/app.js", "css/app.css"],
          },
          outDir: "../priv/static",
          emptyOutDir: true,
        },
        // LV Colocated JS and Hooks
        // https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedJS.html#module-internals
        resolve: {
          alias: {
            "@": ".",
            "phoenix-colocated": `${process.env.MIX_BUILD_PATH}/phoenix-colocated`,
          },
        },
        plugins: [
          tailwindcss(),
          phoenixVitePlugin({
            pattern: /\\.(ex|heex)$/
          })
        ]
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
    Wrap known generated static assets paths with `static_url` calls
    """
    def update_generator_static_assets(igniter, web_module, endpoint) do
      web_folder = Macro.underscore(web_module)
      app_layout_1_8 = Path.join(["lib", web_folder, "components/layouts.ex"])
      app_layout_1_7 = Path.join(["lib", web_folder, "components/layouts/app.html.heex"])

      cond do
        Igniter.exists?(igniter, app_layout_1_8) ->
          update_logo_path_with_static_url(igniter, endpoint, app_layout_1_8)

        Igniter.exists?(igniter, app_layout_1_7) ->
          update_logo_path_with_static_url(igniter, endpoint, app_layout_1_7)

        true ->
          igniter
      end
    end

    defp update_logo_path_with_static_url(igniter, endpoint, path) do
      Igniter.update_file(igniter, path, fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          String.replace(
            content,
            ~s|~p"/images/logo.svg"|,
            ~s|static_url(#{inspect(endpoint)}, ~p"/images/logo.svg")|
          )
        end)
      end)
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
    Remove assets patterns from phoenix_live_reload

    Assets reloading is handled by the vite dev server, not phoenix_live_reload
    """
    def use_only_vite_reloading_for_assets(igniter, app_name, endpoint) do
      Igniter.update_elixir_file(igniter, "config/dev.exs", fn zipper ->
        with {:ok, zipper} <-
               Igniter.Code.Function.move_to_function_call_in_current_scope(
                 zipper,
                 :config,
                 3,
                 fn function_call ->
                   Igniter.Code.Function.argument_equals?(function_call, 0, app_name) &&
                     Igniter.Code.Function.argument_equals?(function_call, 1, endpoint) &&
                     Igniter.Code.Function.argument_matches_predicate?(
                       function_call,
                       2,
                       fn zipper ->
                         Igniter.Code.Keyword.keyword_has_path?(zipper, [:live_reload, :patterns])
                       end
                     )
                 end
               ) do
          Igniter.Code.Function.update_nth_argument(zipper, 2, fn zipper ->
            Igniter.Code.Keyword.put_in_keyword(
              zipper,
              [:live_reload, :patterns],
              [],
              fn zipper ->
                Igniter.Code.List.remove_from_list(zipper, fn zipper ->
                  with {:sigil_r, _, [{:<<>>, _, [regex]}, []]} <- Zipper.node(zipper),
                       true <- String.contains?(regex, "priv/static") do
                    true
                  else
                    _ -> false
                  end
                end)
              end
            )
          end)
        end
      end)
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
    Handle browsers favicon requests by redirecting to the vite dev server.
    """
    def add_favicon_handling_plug(igniter, endpoint) do
      Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        with {:ok, zipper} <-
               Igniter.Code.Common.move_to_last(zipper, &match?({:use, _, _}, Zipper.node(&1))),
             zipper = Igniter.Code.Common.add_code(zipper, "import PhoenixVite.Plug"),
             {:ok, zipper} <-
               Igniter.Code.Common.move_to_last(
                 zipper,
                 &match?({:socket, _, [_, _, _]}, Zipper.node(&1))
               ) do
          plug = """
          plug :favicon, dev_server: {PhoenixVite.Components, :has_vite_watcher?, [__MODULE__]}
          """

          {:ok, Igniter.Code.Common.add_code(zipper, plug)}
        end
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
                  manifest={{#{inspect(app_name)}, "priv/static/.vite/manifest.json"}}
                  dev_server={PhoenixVite.Components.has_vite_watcher?(#{inspect(endpoint)})}
                  to_url={fn p -> static_url(@conn, p) end}
                />
            """
          )
        end)
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
    Use package.json to pull in dependencies
    """
    def adjust_js_dependency_management(igniter) do
      igniter
      |> Igniter.create_new_file("assets/package.json", """
      {
        "dependencies": {
          "phoenix": "file:../deps/phoenix",
          "phoenix_html": "file:../deps/phoenix_html",
          "phoenix_live_view": "file:../deps/phoenix_live_view",
          "topbar": "^3.0.0"
        },
        "devDependencies": {
          "@tailwindcss/vite": "^4.1.0",
          "daisyui": "^5.0.0",
          "phoenix_vite": "file:../deps/phoenix_vite",
          "tailwindcss": "^4.1.0",
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
    end

    @doc """
    Add :bun dependency to project integrated with vite
    """
    def add_bun(igniter, app_name, endpoint) do
      igniter
      |> Igniter.Project.Deps.add_dep(
        {:bun, "~> 1.5", runtime: quote(do: Mix.env() == :dev)},
        append?: true
      )
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
         Sourceror.parse_string!(
           ~s|[args: ~w(x vite), cd: Path.expand("../assets", __DIR__), env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}]|
         )}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [endpoint, :watchers, :vite],
        {:code, Sourceror.parse_string!(~s|{Bun, :install_and_run, [:vite, ~w(dev)]}|)}
      )
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
      |> Igniter.add_task("deps.get")
      |> Igniter.add_task("assets.setup")
    end

    @doc """
    Integrate vite with local node/npm installation
    """
    def add_local_node(igniter, app_name, endpoint) do
      igniter
      |> Igniter.Project.Config.configure(
        "config.exs",
        :phoenix_vite,
        [PhoenixVite.Npm, :assets],
        {:code, Sourceror.parse_string!(~s|[args: [], cd: Path.expand("../assets", __DIR__)]|)}
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :phoenix_vite,
        [PhoenixVite.Npm, :vite],
        {:code,
         Sourceror.parse_string!(
           ~s|[args: ~w(exec -- vite), cd: Path.expand("../assets", __DIR__), env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}]|
         )}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        app_name,
        [endpoint, :watchers, :vite],
        {:code, Sourceror.parse_string!(~s|{PhoenixVite.Npm, :run, [:vite, ~w(dev)]}|)}
      )
      |> Igniter.Project.TaskAliases.modify_existing_alias("assets.setup", fn zipper ->
        alias = Sourceror.parse_string!(~s|["phoenix_vite.npm assets install"]|)
        {:ok, Igniter.Code.Common.replace_code(zipper, alias)}
      end)
      |> Igniter.Project.TaskAliases.modify_existing_alias("assets.build", fn zipper ->
        alias = Sourceror.parse_string!(~s|["phoenix_vite.npm vite build"]|)
        {:ok, Igniter.Code.Common.replace_code(zipper, alias)}
      end)
      |> Igniter.Project.TaskAliases.modify_existing_alias("assets.deploy", fn zipper ->
        alias = Sourceror.parse_string!(~s|["assets.build"]|)
        {:ok, Igniter.Code.Common.replace_code(zipper, alias)}
      end)
      |> Igniter.add_task("assets.setup")
    end
  end
end
