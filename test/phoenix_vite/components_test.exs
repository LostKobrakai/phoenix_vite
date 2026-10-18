defmodule PhoenixVite.ComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias PhoenixVite.{Components, Manifest}

  @manifest Manifest.parse(%{
              "js/app.js" => %{
                "file" => "assets/app-C-lebOsX.js",
                "isEntry" => true,
                "imports" => ["_shared.js"],
                "css" => ["assets/app-Bx2.css"],
                "dynamicImports" => ["js/page.js"]
              },
              "_shared.js" => %{
                "file" => "assets/shared-Dk2s9.js",
                "css" => ["assets/shared-BE15pjT4.css"]
              },
              "js/page.js" => %{
                "file" => "assets/page-Mq7.js",
                "isDynamicImport" => true,
                "css" => ["assets/page-Zt4.css"]
              }
            })

  defp assets(attrs) do
    render_component(
      &Components.assets/1,
      Keyword.merge([names: ["js/app.js"], manifest: @manifest], attrs)
    )
  end

  defp prefetched(html) do
    [_, json] = Regex.run(~r/const queue = (.*)$/m, html)
    JSON.decode!(json)
  end

  describe "assets/1 with prefetch" do
    test "renders the files behind dynamic imports" do
      html = assets(prefetch: true, to_url: &("https://cdn.test" <> &1), crossorigin: true)

      assert [script, style] = prefetched(html)

      assert script == %{
               "rel" => "prefetch",
               "fetchpriority" => "low",
               "as" => "script",
               "href" => "https://cdn.test/assets/page-Mq7.js",
               "crossorigin" => ""
             }

      assert %{"as" => "style", "href" => "https://cdn.test/assets/page-Zt4.css"} = style
      assert html =~ ~s[window.addEventListener("load",]
      assert html =~ "let i = null || queue.length"
      refute html =~ "&quot;"
    end

    test "takes concurrency and event" do
      html = assets(prefetch: [concurrency: 2, event: "app:ready"])

      assert html =~ "let i = 2 || queue.length"
      assert html =~ ~s[window.addEventListener("app:ready",]
    end

    test "sets the nonce on the script" do
      assert assets(prefetch: true, nonce: "abc") =~
               ~r/<script nonce="abc">\s*\(\(\) => \{\s*const queue/
    end

    test "escapes what could close the script" do
      html = assets(prefetch: [event: "</script><script>alert(1)"])

      refute html =~ "</script><script>"
      assert html =~ ~S["\u003c/script>\u003cscript>alert(1)"]
    end

    test "refuses an unknown option" do
      assert_raise ArgumentError, fn -> assets(prefetch: [wait: 1]) end
    end

    test "renders nothing when off, on the dev server, or without dynamic imports" do
      refute assets([]) =~ "const queue"
      refute assets(prefetch: true, dev_server: true) =~ "const queue"
      refute assets(prefetch: true, names: ["js/page.js"]) =~ "const queue"
    end
  end

  describe "assets/1 with nonce" do
    test "sets it on every tag from the manifest, preloads included" do
      html = assets(nonce: "abc")

      assert length(Regex.scan(~r/<(script|link)/, html)) == 4
      assert length(Regex.scan(~r/nonce="abc"/, html)) == 4
    end

    test "sets it on every tag from the dev server" do
      html = assets(names: ["js/app.js", "css/app.css"], dev_server: true, nonce: "abc")

      assert length(Regex.scan(~r/nonce="abc"/, html)) == 3
    end
  end
end
