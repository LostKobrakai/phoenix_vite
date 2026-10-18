defmodule PhoenixVite.Manifest do
  defmodule Chunk do
    @type t :: %__MODULE__{
            key: String.t(),
            file: String.t(),
            src: String.t() | nil,
            name: String.t() | nil,
            is_entry?: boolean(),
            is_dynamic_import?: boolean(),
            assets: [String.t()],
            css: [String.t()],
            dynamicImports: [String.t()],
            names: [String.t()],
            imports: [String.t()]
          }
    defstruct [
      :key,
      :file,
      :src,
      :name,
      is_entry?: false,
      is_dynamic_import?: false,
      assets: [],
      css: [],
      dynamicImports: [],
      names: [],
      imports: []
    ]
  end

  def parse(%{} = chunks_map) do
    Map.new(chunks_map, fn {key, chunk} ->
      chunk = %Chunk{
        key: key,
        file: Map.fetch!(chunk, "file"),
        src: Map.get(chunk, "src"),
        name: Map.get(chunk, "name"),
        is_entry?: Map.get(chunk, "isEntry", false),
        is_dynamic_import?: Map.get(chunk, "isDynamicImport", false),
        assets: Map.get(chunk, "assets", []),
        css: Map.get(chunk, "css", []),
        dynamicImports: Map.get(chunk, "dynamicImports", []),
        names: Map.get(chunk, "names", []),
        imports: Map.get(chunk, "imports", [])
      }

      {key, chunk}
    end)
  end

  def parse(json) when is_binary(json) do
    json
    |> JSON.decode!()
    |> parse()
  end

  def parse({app, path}) do
    app
    |> Application.app_dir(path)
    |> File.read!()
    |> parse()
  end

  # https://vite.dev/guide/backend-integration.html
  def imported_chunks(%{} = manifest, name) do
    manifest
    |> Map.fetch!(name)
    |> Map.fetch!(:imports)
    |> reachable(manifest, [:imports])
  end

  # Chunks reachable through dynamic imports, minus what the entries already load
  def prefetched_files(%{} = manifest, names) do
    names = Enum.map(names, &Path.relative/1)

    loaded =
      for name <- names,
          chunk <- reachable([name], manifest, [:imports]),
          file <- [chunk.file | chunk.css],
          into: MapSet.new(),
          do: file

    chunks =
      names
      |> Enum.flat_map(&Map.fetch!(manifest, &1).dynamicImports)
      |> reachable(manifest, [:imports, :dynamicImports])

    for chunk <- chunks,
        file <- [chunk.file | chunk.css],
        file not in loaded,
        uniq: true,
        do: file
  end

  defp reachable(worklist, manifest, edges, seen \\ %{})

  defp reachable([], _manifest, _edges, _seen), do: []

  defp reachable([name | rest], manifest, edges, seen) when is_map_key(seen, name) do
    reachable(rest, manifest, edges, seen)
  end

  defp reachable([name | rest], manifest, edges, seen) do
    chunk = Map.fetch!(manifest, name)
    seen = Map.put(seen, name, true)
    next = Enum.flat_map(edges, &Map.fetch!(chunk, &1))
    [chunk | reachable(next ++ rest, manifest, edges, seen)]
  end

  def cache_static_manifest_latest(%{} = manifest) do
    Map.new(manifest, fn {key, %Chunk{file: file}} -> {key, file} end)
  end
end
