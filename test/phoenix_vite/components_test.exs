defmodule PhoenixVite.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias PhoenixVite.Components
  alias PhoenixVite.Manifest

  test "adds script attributes to development scripts" do
    html =
      render_component(&Components.assets/1, %{
        names: ["js/app.tsx", "css/app.css"],
        manifest: %{},
        dev_server: true,
        script_attrs: %{nonce: "request-nonce"},
        to_url: &"http://localhost:5173#{&1}"
      })

    assert length(Regex.scan(~r/nonce="request-nonce"/, html)) == 2
    assert html =~ ~s(src="http://localhost:5173/@vite/client")
    assert html =~ ~s(src="http://localhost:5173/js/app.tsx")
    refute html =~ ~r/<link[^>]+nonce="request-nonce"/
  end

  test "adds script attributes to production entry and imported chunks" do
    manifest =
      Manifest.parse(%{
        "js/app.tsx" => %{
          "css" => ["assets/app.css"],
          "file" => "assets/app.js",
          "imports" => ["shared.js"]
        },
        "shared.js" => %{"file" => "assets/shared.js"}
      })

    html =
      render_component(&Components.assets/1, %{
        names: ["js/app.tsx"],
        manifest: manifest,
        dev_server: false,
        script_attrs: %{nonce: "request-nonce"}
      })

    assert length(Regex.scan(~r/nonce="request-nonce"/, html)) == 2
    assert html =~ ~s(src="/assets/app.js?vsn=d")
    assert html =~ ~r/<link[^>]+rel="modulepreload"[^>]+href="\/assets\/shared\.js"/
    assert length(Regex.scan(~r/<script/, html)) == 1
    refute html =~ ~r/<link[^>]+rel="stylesheet"[^>]+nonce="request-nonce"/
  end

  test "rejects component-owned script attributes" do
    assert_raise ArgumentError, ~r/script_attrs cannot override/, fn ->
      render_component(&Components.assets/1, %{
        names: ["js/app.tsx"],
        manifest: %{},
        dev_server: true,
        script_attrs: %{"type" => "text/plain", src: "https://example.com/other.js"}
      })
    end
  end
end
