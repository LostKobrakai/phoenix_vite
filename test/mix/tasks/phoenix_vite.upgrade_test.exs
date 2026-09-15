defmodule Mix.Tasks.PhoenixVite.UpgradeTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  test "0.6.0 splits static caching into a vite assets plug and a plain plug" do
    phx_test_project()
    |> Igniter.compose_task("phoenix_vite.upgrade", ["0.5.1", "0.6.0"])
    |> assert_has_patch("lib/test_web/endpoint.ex", """
    + |  plug Plug.Static,
    + |    at: "/",
    + |    from: :test,
    + |    gzip: not code_reloading?,
    + |    only: ["assets"],
    + |    cache_control_for_etags: "public, max-age=31536000, immutable"
    + |
    """)
    |> assert_has_patch("lib/test_web.ex", """
    - |  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
    + |  # assets/ is served separately, by a dedicated Plug.Static plug
    + |  def static_paths, do: ~w(fonts images favicon.ico robots.txt)
    """)
  end

  test "is a no-op when the target range doesn't cross a registered version" do
    phx_test_project()
    |> Igniter.compose_task("phoenix_vite.upgrade", ["0.5.0", "0.5.1"])
    |> assert_unchanged("lib/test_web/endpoint.ex")
    |> assert_unchanged("lib/test_web.ex")
  end
end
