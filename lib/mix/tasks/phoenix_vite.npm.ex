defmodule Mix.Tasks.PhoenixVite.Npm do
  @moduledoc """
  Invokes npm with the given args.

  Usage:

      $ mix phoenix_vite.npm PROFILE ARGS

  """

  @shortdoc "Invokes node with the profile and args"
  use Mix.Task

  @requirements ["app.config"]

  @impl true
  def run(args) do
    switches = []
    {_opts, remaining_args} = OptionParser.parse_head!(args, switches: switches)

    Application.ensure_all_started(:phoenix_vite)

    Mix.Task.reenable("phoenix_vite.npm")
    run_cmd(remaining_args)
  end

  defp run_cmd([profile | args] = all) do
    case PhoenixVite.Npm.run(String.to_atom(profile), args) do
      0 -> :ok
      status -> Mix.raise("`mix phoenix_vite.npm #{Enum.join(all, " ")}` exited with #{status}")
    end
  end

  defp run_cmd([]) do
    Mix.raise("`mix phoenix_vite.npm` expects the profile as argument")
  end
end
