defmodule PhoenixVite.IgniterTest do
  use ExUnit.Case, async: true
  import Igniter.Test
  alias PhoenixVite.Igniter, as: ViteIgniter

  describe "create_vite_config/1" do
    test "creates a minimal vite.config.mjs" do
      phx_test_project()
      |> ViteIgniter.create_vite_config()
      |> assert_creates("assets/vite.config.mjs", """
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

    test "loads app.css when it exists outside of the rewrite sources" do
      path = "assets/css/app.css"
      igniter = phx_test_project()

      assert Igniter.exists?(igniter, path)
      igniter = %{igniter | rewrite: Rewrite.delete(igniter.rewrite, path)}
      refute Rewrite.has_source?(igniter.rewrite, path)

      igniter = ViteIgniter.create_vite_config(igniter)
      {:ok, source} = Rewrite.source(igniter.rewrite, "assets/vite.config.mjs")

      assert Rewrite.Source.get(source, :content) =~
               ~s(import tailwindcss from "@tailwindcss/vite")
    end
  end

  describe "configure_dev_server_static_url_for_development/3" do
    test "adds the correct configuration" do
      phx_test_project()
      |> ViteIgniter.configure_dev_server_static_url_for_development(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/dev.exs", """
      20    - |  ]
         20 + |  ],
         21 + |  static_url: [host: "localhost", port: 5173]
      """)
    end
  end

  describe "update_generator_static_assets/1" do
    test "updates logo" do
      phx_test_project()
      |> ViteIgniter.update_generator_static_assets(TestWeb, TestWeb.Endpoint)
      |> assert_has_patch("lib/test_web/components/layouts.ex", """
      41     - |          <img src={~p"/images/logo.svg"} width="36" />
          41 + |          <img src={static_url(TestWeb.Endpoint, ~p"/images/logo.svg")} width="36" />
      """)
    end
  end

  describe "use_only_vite_assets_caching/3" do
    test "removes cache_static_manifest config from prod.exs" do
      phx_test_project()
      |> ViteIgniter.use_only_vite_assets_caching(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/prod.exs", """
      8    - |config :test, TestWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"
         8 + |config :test, TestWeb.Endpoint, []
      """)
    end

    test "configures cache_static_manifest_latest with contents of the vite manifest" do
      phx_test_project()
      |> ViteIgniter.use_only_vite_assets_caching(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/runtime.exs", """
      69 + |    cache_static_manifest_latest: PhoenixVite.cache_static_manifest_latest(:test)
      """)
    end
  end

  describe "use_only_vite_reloading_for_assets/3" do
    test "removes assets patterns config from runtime.exs" do
      phx_test_project()
      |> ViteIgniter.use_only_vite_reloading_for_assets(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/runtime.exs", """
      32    - |        ~r"priv/static/(?!uploads/).*\\.(js|css|png|jpeg|jpg|gif|svg)$"
      """)
    end
  end

  describe "add_module_preload_polyfill/1" do
    test "updates the app.js with the polyfill import" do
      igniter =
        phx_test_project()
        |> ViteIgniter.add_module_preload_polyfill()

      assert diff(igniter) =~ """
             Update: assets/js/app.js

                 1 + |import "vite/modulepreload-polyfill";
              1  2   |// If you want to use Phoenix channels, run `mix help phx.gen.channel`
              2  3   |// to get started and then uncomment the line below.
             """
    end
  end

  describe "use_vite_public_folder_for_static_assets/1" do
    test "moves all hardcoded priv/static files to assets/public" do
      igniter =
        phx_test_project()
        |> ViteIgniter.use_vite_public_folder_for_static_assets()

      assert {"priv/static/favicon.ico", "assets/public/favicon.ico"} in igniter.moves
    end

    test "adjusts .gitignore" do
      igniter =
        phx_test_project()
        |> ViteIgniter.use_vite_public_folder_for_static_assets()

      assert diff(igniter) =~ """
             29    - |/priv/static/assets/
                29 + |/priv/static/*
             30 30   |
             31    - |# Ignore digested assets cache.
             32    - |/priv/static/cache_manifest.json
             33    - |
             """
    end
  end

  describe "add_favicon_handling_plug/2" do
    test "updates the endpoint with the import and plug" do
      phx_test_project()
      |> ViteIgniter.add_favicon_handling_plug(TestWeb.Endpoint)
      |> assert_has_patch("lib/test_web/endpoint.ex", """
      2  2   |  use Phoenix.Endpoint, otp_app: :test
         3 + |  import PhoenixVite.Plug
      """)
      |> assert_has_patch("lib/test_web/endpoint.ex", """
         20 + |  plug :favicon, dev_server: {PhoenixVite.Components, :has_vite_watcher?, [__MODULE__]}
         21 + |
      19 22   |  # Serve at "/" the static files from "priv/static" directory.
      """)
    end
  end

  describe "link_root_layout_to_vite/4" do
    test "updates root layout with phoenix_vite component usage" do
      igniter =
        phx_test_project()
        |> ViteIgniter.link_root_layout_to_vite(:test, TestWeb.Endpoint, TestWeb)

      assert diff(igniter) =~ """
              8    - |    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
              9    - |    <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
             10    - |    </script>
                 8 + |    <PhoenixVite.Components.assets
                 9 + |      names={["js/app.js", "css/app.css"]}
                10 + |      manifest={{:test, "priv/static/.vite/manifest.json"}}
                11 + |      dev_server={PhoenixVite.Components.has_vite_watcher?(TestWeb.Endpoint)}
                12 + |      to_url={fn p -> static_url(@conn, p) end}
                13 + |    />
             """
    end
  end

  describe "remove_default_assets_handling/3" do
    test "removes watchers from dev.exs" do
      phx_test_project()
      |> ViteIgniter.remove_default_assets_handling(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/dev.exs", """
      17    - |  watchers: [
      18    - |    esbuild: {Esbuild, :install_and_run, [:test, ~w(--sourcemap=inline --watch)]},
      19    - |    tailwind: {Tailwind, :install_and_run, [:test, ~w(--watch)]}
      20    - |  ]
         17 + |  watchers: []
      """)
    end

    test "removes app config from config.exs" do
      phx_test_project()
      |> ViteIgniter.remove_default_assets_handling(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/config.exs", """
      39    - |# Configure esbuild (the version is required)
      40    - |config :esbuild,
      41    - |  version: "0.25.4",
      42    - |  test: [
      43    - |    args:
      44    - |      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      45    - |    cd: Path.expand("../assets", __DIR__),
      46    - |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
      47    - |  ]
      48    - |
      49    - |# Configure tailwind (the version is required)
      50    - |config :tailwind,
      51    - |  version: "4.3.0",
      52    - |  test: [
      53    - |    args: ~w(
      54    - |      --input=assets/css/app.css
      55    - |      --output=priv/static/assets/css/app.css
      56    - |    ),
      57    - |    cd: Path.expand("..", __DIR__),
      58    - |    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
      59    - |  ]
      60    - |
      """)
    end

    test "removes dependencies" do
      phx_test_project()
      |> ViteIgniter.remove_default_assets_handling(:test, TestWeb.Endpoint)
      |> assert_has_patch("mix.exs", """
      52    - |      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      53    - |      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      """)
    end

    test "queues mix deps.clean --unused --unlock" do
      phx_test_project()
      |> ViteIgniter.remove_default_assets_handling(:test, TestWeb.Endpoint)
      |> assert_has_task("deps.clean", ["--unlock", "--unused", "esbuild"])
      |> assert_has_task("deps.clean", ["--unlock", "--unused", "tailwind"])
    end
  end

  describe "adjust_js_dependency_management/1" do
    test "adds package.json" do
      phx_test_project()
      |> ViteIgniter.adjust_js_dependency_management()
      |> assert_creates("assets/package.json", """
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
    end

    test "replaces vendored depedendencies with npm ones" do
      phx_test_project()
      |> ViteIgniter.adjust_js_dependency_management()
      |> assert_rms([
        "assets/vendor/topbar.js"
      ])
      |> assert_has_patch("assets/js/app.js", """
      26    - |import topbar from "../vendor/topbar"
         26 + |import topbar from "topbar"
      """)
      |> assert_has_patch("assets/css/app.css", """
      17     - |@plugin "daisyui/packages/bundle/daisyui" {
          17 + |@plugin "daisyui" {
      """)
      |> assert_has_patch("assets/css/app.css", """
      24     - |@plugin "daisyui/packages/bundle/daisyui-theme" {
          24 + |@plugin "daisyui/theme" {
      """)
      |> assert_has_patch("assets/css/app.css", """
      59     - |@plugin "daisyui/packages/bundle/daisyui-theme" {
          59 + |@plugin "daisyui/theme" {
      """)
      |> assert_has_patch("mix.exs", """
      61 - |      {:daisyui,
      """)
    end
  end

  describe "add_bun/3" do
    test "adds dependency on bun package" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_patch("mix.exs", """
      76 + |      {:bun, "~> 2.0", runtime: Mix.env() == :dev}
      """)
    end

    test "configures bun version and profiles" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/config.exs", """
      10 + |config :bun,
      11 + |  version: "1.2.16",
      12 + |  assets: [args: [], cd: Path.expand("../assets", __DIR__)],
      13 + |  vite: [
      14 + |    args: ~w(x vite),
      15 + |    cd: Path.expand("../assets", __DIR__),
      16 + |    env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}
      17 + |  ]
      """)
    end

    test "configures endpoint watcher" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/dev.exs", """
      20 + |    vite: {Bun, :install_and_run, [:vite, ~w(dev)]}
      """)
    end

    test "queues setup tasks" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_task("deps.get", [])
      |> assert_has_task("assets.setup", [])
    end

    test "updates tasks" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_patch("mix.exs", """
      91     - |      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      92     - |      "assets.build": ["compile", "tailwind test", "esbuild test"],
          92 + |      "assets.setup": ["bun.install --if-missing", "bun assets install"],
          93 + |      "assets.build": ["bun vite build"],
      93  94   |      "assets.deploy": [
      94     - |        "tailwind test --minify",
      95     - |        "esbuild test --minify",
      96     - |        "phx.digest"
          95 + |        "assets.build"
      97  96   |      ]
      """)
    end
  end

  describe "add_local_node/3" do
    test "configures profiles" do
      phx_test_project()
      |> ViteIgniter.add_local_node(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/config.exs", """
      10 + |config :phoenix_vite, PhoenixVite.Npm,
      11 + |  assets: [args: [], cd: Path.expand("../assets", __DIR__)],
      12 + |  vite: [
      13 + |    args: ~w(exec -- vite),
      14 + |    cd: Path.expand("../assets", __DIR__),
      15 + |    env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}
      16 + |  ]
      """)
    end

    test "configures endpoint watcher" do
      phx_test_project()
      |> ViteIgniter.add_local_node(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/dev.exs", """
      20 + |    vite: {PhoenixVite.Npm, :run, [:vite, ~w(dev)]}
      """)
    end

    test "queues setup tasks" do
      phx_test_project()
      |> ViteIgniter.add_local_node(:test, TestWeb.Endpoint)
      |> assert_has_task("assets.setup", [])
    end

    test "updates tasks" do
      phx_test_project()
      |> ViteIgniter.add_local_node(:test, TestWeb.Endpoint)
      |> assert_has_patch("mix.exs", """
      91     - |      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      92     - |      "assets.build": ["compile", "tailwind test", "esbuild test"],
          91 + |      "assets.setup": ["phoenix_vite.npm assets install"],
          92 + |      "assets.build": ["phoenix_vite.npm vite build"],
      93  93   |      "assets.deploy": [
      94     - |        "tailwind test --minify",
      95     - |        "esbuild test --minify",
      96     - |        "phx.digest"
          94 + |        "assets.build"
      97  95   |      ]
      """)
    end
  end
end
