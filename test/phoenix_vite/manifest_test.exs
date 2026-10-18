defmodule PhoenixVite.ManifestTest do
  use ExUnit.Case, async: true
  alias PhoenixVite.Manifest

  describe "parse/1" do
    test "with json" do
      json = """
      {
        "js/app.js": {
          "file": "assets/app-C-lebOsX.js",
          "name": "app",
          "src": "js/app.js",
          "isEntry": true,
          "css": [
            "assets/app-BE15pjT4.css"
          ]
        }
      }
      """

      map = Manifest.parse(json)

      assert map_size(map) == 1

      %Manifest.Chunk{} = chunk = Map.fetch!(map, "js/app.js")

      assert chunk.key == "js/app.js"
      assert chunk.file == "assets/app-C-lebOsX.js"
      assert chunk.src == "js/app.js"
      assert chunk.name == "app"
      assert chunk.is_entry? == true
      assert chunk.is_dynamic_import? == false
      assert chunk.assets == []
      assert chunk.css == ["assets/app-BE15pjT4.css"]
      assert chunk.dynamicImports == []
      assert chunk.names == []
      assert chunk.imports == []
    end
  end

  describe "imported_chunks/2" do
    test "works" do
      json = """
      {
        "js/app.js": {
          "file": "assets/app-C-lebOsX.js",
          "name": "app",
          "src": "js/app.js",
          "isEntry": true,
          "css": [
            "assets/app-BE15pjT4.css"
          ]
        }
      }
      """

      manifest = Manifest.parse(json)

      assert [] = Manifest.imported_chunks(manifest, "js/app.js")
    end
  end

  describe "prefetched_files/2" do
    @json """
    {
      "_shared.js": {
        "file": "assets/shared-B7PI925R.js",
        "css": ["assets/shared-ChJ_j-JJ.css"]
      },
      "_chart.js": {
        "file": "assets/chart-Dq2nYz1.js"
      },
      "baz.js": {
        "file": "assets/baz-B2H3sXNv.js",
        "imports": ["_shared.js"],
        "dynamicImports": ["deep.js"],
        "css": ["assets/baz-Xk2dQ.css"]
      },
      "deep.js": {
        "file": "assets/deep-Hq8wK.js",
        "imports": ["_chart.js", "_shared.js"]
      },
      "views/bar.js": {
        "file": "assets/bar-gkvgaI9m.js",
        "isEntry": true,
        "imports": ["_shared.js"],
        "dynamicImports": ["baz.js"]
      }
    }
    """

    test "walks dynamic imports, leaving out what the entry loads" do
      assert Manifest.prefetched_files(Manifest.parse(@json), ["views/bar.js"]) == [
               "assets/baz-B2H3sXNv.js",
               "assets/baz-Xk2dQ.css",
               "assets/deep-Hq8wK.js",
               "assets/chart-Dq2nYz1.js"
             ]
    end

    test "is empty without dynamic imports" do
      assert Manifest.prefetched_files(Manifest.parse(@json), ["deep.js"]) == []
    end
  end
end
