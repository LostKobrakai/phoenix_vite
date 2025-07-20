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
        plugins: [
          tailwindcss(),
          phoenixVitePlugin()
        ]
      });
      """)
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
      |> ViteIgniter.update_generator_static_assets(TestWeb)
      |> assert_has_patch("lib/test_web/components/layouts.ex", """
      37     - |          <img src={~p"/images/logo.svg"} width="36" />
          37 + |          <img src={static_url(@conn, ~p"/images/logo.svg")} width="36" />
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
      52 + |    cache_static_manifest_latest: PhoenixVite.cache_static_manifest_latest(:test)
      """)
    end
  end

  describe "use_only_vite_reloading_for_assets/3" do
    test "removes assets patterns config from dev.exs" do
      phx_test_project()
      |> ViteIgniter.use_only_vite_reloading_for_assets(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/dev.exs", """
      60    - |      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
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

  describe "link_root_layout_to_vite/4" do
    test "updates root layout with phoenix_vite component usage" do
      igniter =
        phx_test_project()
        |> ViteIgniter.link_root_layout_to_vite(:test, TestWeb.Endpoint, TestWeb)

      assert diff(igniter) =~ """
             10    - |    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
             11    - |    <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
             12    - |    </script>
                10 + |    <PhoenixVite.Components.assets
                11 + |      names={["js/app.js", "css/app.css"]}
                12 + |      manifest={{:test, "priv/static/.vite/manifest.json"}}
                13 + |      dev_server={PhoenixVite.Components.has_vite_watcher?(TestWeb.Endpoint)}
                14 + |      to_url={fn p -> static_url(@conn, p) end}
                15 + |    />
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
      34    - |# Configure esbuild (the version is required)
      35    - |config :esbuild,
      36    - |  version: "0.17.11",
      37    - |  test: [
      38    - |    args:
      39    - |      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
      40    - |    cd: Path.expand("../assets", __DIR__),
      41    - |    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
      42    - |  ]
      43    - |
      44    - |# Configure tailwind (the version is required)
      45    - |config :tailwind,
      46    - |  version: "4.0.9",
      47    - |  test: [
      48    - |    args: ~w(
      49    - |      --input=assets/css/app.css
      50    - |      --output=priv/static/assets/css/app.css
      51    - |    ),
      52    - |    cd: Path.expand("..", __DIR__)
      53    - |  ]
      54    - |
      """)
    end

    test "removes dependencies" do
      phx_test_project()
      |> ViteIgniter.remove_default_assets_handling(:test, TestWeb.Endpoint)
      |> assert_has_patch("mix.exs", """
      45    - |      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      46    - |      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
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
        "assets/vendor/topbar.js",
        "assets/vendor/daisyui.js",
        "assets/vendor/daisyui-theme.js"
      ])
      |> assert_has_patch("assets/js/app.js", """
      25    - |import topbar from "../vendor/topbar"
         25 + |import topbar from "topbar"
      """)
      |> assert_has_patch("assets/css/app.css", """
      16     - |@plugin "../vendor/daisyui" {
          16 + |@plugin "daisyui" {
      """)
      |> assert_has_patch("assets/css/app.css", """
      24     - |@plugin "../vendor/daisyui-theme" {
          24 + |@plugin "daisyui/theme" {
      """)
      |> assert_has_patch("assets/css/app.css", """
      59     - |@plugin "../vendor/daisyui-theme" {
          59 + |@plugin "daisyui/theme" {
      """)
    end
  end

  describe "add_bun/3" do
    test "adds dependency on bun package" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_patch("mix.exs", """
      62 + |      {:bun, "~> 1.5", runtime: Mix.env() == :dev}
      """)
    end

    test "configures bun version and profiles" do
      phx_test_project()
      |> ViteIgniter.add_bun(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/config.exs", """
      10 + |config :bun,
      11 + |  version: "1.2.16",
      12 + |  assets: [args: [], cd: Path.expand("../assets", __DIR__)],
      13 + |  vite: [args: ~w(x vite), cd: Path.expand("../assets", __DIR__)]
      14 + |
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
      77    - |      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      78    - |      "assets.build": ["tailwind test", "esbuild test"],
         78 + |      "assets.setup": ["bun.install --if-missing", "bun assets install"],
         79 + |      "assets.build": ["bun vite build"],
      79 80   |      "assets.deploy": [
      80    - |        "tailwind test --minify",
      81    - |        "esbuild test --minify",
      82    - |        "phx.digest"
         81 + |        "assets.build"
      83 82   |      ]
      """)
    end
  end

  describe "add_local_node/3" do
    test "configures endpoint watcher" do
      phx_test_project()
      |> ViteIgniter.add_local_node(:test, TestWeb.Endpoint)
      |> assert_has_patch("config/dev.exs", """
      20 + |    vite: {System, :cmd, ["npx", ~w(vite dev), [cd: "assets"]]}
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
      77    - |      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      78    - |      "assets.build": ["tailwind test", "esbuild test"],
         77 + |      "assets.setup": ["cmd --cd assets npm install"],
         78 + |      "assets.build": ["cmd --cd assets npx vite build"],
      79 79   |      "assets.deploy": [
      80    - |        "tailwind test --minify",
      81    - |        "esbuild test --minify",
      82    - |        "phx.digest"
         80 + |        "assets.build"
      83 81   |      ]
      """)
    end
  end
end
