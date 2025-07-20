defmodule Mix.Tasks.PhoenixVite.Install.Helper do
  @moduledoc false

  defmacro with_igniter(do: do_block, else: else_block) do
    if Code.ensure_loaded?(Igniter) do
      do_block
    else
      else_block
    end
  end
end

defmodule Mix.Tasks.PhoenixVite.Install do
  @shortdoc "Installer for Phoenix Vite"
  @example "mix phoenix_vite.install --bun"

  @moduledoc """
  #{@shortdoc}

  Sets a freshly generated phoenix app up to use the vite js build tool.

  ## Example

  ```sh
  #{@example}
  ```

  ## Options

  * `--bun` or `-b` - Use the `:bun` elixir package to run vite.
  """
  import Mix.Tasks.PhoenixVite.Install.Helper

  with_igniter do
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_vite,
        example: @example,
        schema: [bun: :boolean],
        defaults: [bun: false],
        aliases: [b: :bun],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Igniter.Project.Application.app_name(igniter)
      {igniter, endpoint} = Igniter.Libs.Phoenix.select_endpoint(igniter)
      web_module = Igniter.Libs.Phoenix.web_module(igniter)

      igniter =
        igniter
        |> PhoenixVite.Igniter.create_vite_config()
        |> PhoenixVite.Igniter.configure_dev_server_static_url_for_development(app_name, endpoint)
        |> PhoenixVite.Igniter.update_generator_static_assets(web_module)
        |> PhoenixVite.Igniter.use_only_vite_assets_caching(app_name, endpoint)
        |> PhoenixVite.Igniter.use_only_vite_reloading_for_assets(app_name, endpoint)
        |> PhoenixVite.Igniter.add_module_preload_polyfill()
        |> PhoenixVite.Igniter.use_vite_public_folder_for_static_assets()
        |> PhoenixVite.Igniter.link_root_layout_to_vite(app_name, endpoint, web_module)
        |> PhoenixVite.Igniter.remove_default_assets_handling(app_name, endpoint)
        |> PhoenixVite.Igniter.adjust_js_dependency_management()

      if igniter.args.options[:bun] do
        PhoenixVite.Igniter.add_bun(igniter, app_name, endpoint)
      else
        PhoenixVite.Igniter.add_local_node(igniter, app_name, endpoint)
      end
    end
  else
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_vite.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
