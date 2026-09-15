defmodule Mix.Tasks.PhoenixVite.Upgrade do
  @shortdoc "Upgrades a project using phoenix_vite between versions"
  @example "mix phoenix_vite.upgrade 0.5.1 0.6.0"

  @moduledoc """
  #{@shortdoc}

  Runs the code modifications registered for every phoenix_vite version between
  `from` (exclusive) and `to` (inclusive). This is also picked up automatically
  by `mix igniter.upgrade phoenix_vite`.

  ## Example

  ```sh
  #{@example}
  ```
  """
  import Mix.Tasks.PhoenixVite.Install.Helper

  with_igniter do
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_vite,
        example: @example,
        positional: [:from, :to],
        schema: [],
        defaults: [],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      positional = igniter.args.positional
      options = igniter.args.options

      # For each version that requires a change, add it to this map. Each key
      # is a version that points at a list of functions taking an igniter and
      # options, run in order for every version in (from, to].
      upgrades = %{
        "0.6.0" => [&upgrade_to_0_6_0/2]
      }

      Igniter.Upgrades.run(igniter, positional.from, positional.to, upgrades, options)
    end

    defp upgrade_to_0_6_0(igniter, _opts) do
      app_name = Igniter.Project.Application.app_name(igniter)
      {igniter, endpoint} = Igniter.Libs.Phoenix.select_endpoint(igniter)
      web_module = Igniter.Libs.Phoenix.web_module(igniter)

      PhoenixVite.Igniter.split_plug_static_for_caching(igniter, app_name, web_module, endpoint)
    end
  else
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_vite.upgrade' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
