defmodule PhoenixVite.Npm do
  @doc """
  Run a npm command
  """
  def run(profile, extra_args) do
    config = config_for!(profile)
    args = (config[:args] || []) ++ extra_args

    {_, exit_status} =
      System.cmd("npm", args,
        cd: config[:cd] || File.cwd!(),
        env: config[:env] || %{},
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    exit_status
  end

  defp config_for!(profile) when is_atom(profile) do
    Application.get_env(:phoenix_vite, __MODULE__, [])
    |> Keyword.get_lazy(profile, fn ->
      raise ArgumentError, """
      unknown profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :phoenix_vite, #{__MODULE__},
            #{profile}: [
              args: ~w(…),
              cd: Path.expand("../assets", __DIR__),
              env: %{"ENV_VAR" => "value"}
            ]
      """
    end)
  end
end
