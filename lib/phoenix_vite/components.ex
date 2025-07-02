defmodule PhoenixVite.Components do
  @moduledoc """
  Vite related components to be used within your phoenix application.

  ## Usage

  Put the following into your `<head />` of your phoenix root layout:

      <PhoenixVite.Components.assets
        names={["js/app.js", "css/app.css"]}
        manifest={{:my_app, "priv/static/.vite/manifest.json"}}
        dev_server={PhoenixVite.Components.has_vite_watcher?(MyAppWeb.Endpoint)}
      />

  If you want to make use of the dev server you need to provide the `to_url` option.

      <PhoenixVite.Components.assets
        names={["js/app.js", "css/app.css"]}
        manifest={{:my_app, "priv/static/.vite/manifest.json"}}
        dev_server={PhoenixVite.Components.has_vite_watcher?(MyAppWeb.Endpoint)}
        to_url={fn p -> static_url(@conn, p) end}
      />

  This also requires having the static_url configured for the endpoint.

      config :myapp, MyAppWeb.Endpoint,
        static_url: [host: "localhost", port: 5173]

  """
  use Phoenix.Component
  alias PhoenixVite.Manifest

  @doc """
  Checks for a conventional `:vite` key in the endpoints `:watchers` list.
  """
  @spec has_vite_watcher?(phoenix_endpoint :: module) :: boolean
  def has_vite_watcher?(endpoint) do
    Keyword.has_key?(endpoint.config(:watchers, []), :vite)
  end

  @doc """
  Asset references of vite to be placed into the `<head />` of a html page.

  Switches between dev server provided resources or static resources based
  on a vite manifest file.
  """
  attr :names, :list, required: true
  attr :manifest, :any, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1
  attr :dev_server, :boolean, default: false

  def assets(%{dev_server: true} = assigns) do
    assets_from_dev_server(assigns)
  end

  def assets(%{dev_server: false} = assigns) do
    assets_from_manifest(assigns)
  end

  @doc """
  Asset references of vite dev server to be placed into the `<head />` of a html page.
  """
  attr :names, :list, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1

  # https://vite.dev/guide/backend-integration.html
  def assets_from_dev_server(assigns) do
    ~H"""
    <script phx-track-static type="module" src={@to_url.("/@vite/client")}>
    </script>
    <.reference_for_file :for={name <- @names} file={name} to_url={@to_url} />
    """
  end

  @doc """
  Asset references of vite manifest to be placed into the `<head />` of a html page.

  Caches manifests at runtime when refernces require parsing per provided source.
  """
  attr :name, :string, required: true
  attr :manifest, :any, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1

  # https://vite.dev/guide/backend-integration.html
  def assets_from_manifest(%{manifest: manifest} = assigns) do
    manifest = cached_manifest(manifest)
    assigns = assign(assigns, manifest: cached_manifest(manifest))

    ~H"""
    <.assets_from_manifest_for_name
      :for={name <- @names}
      name={name}
      manifest={@manifest}
      to_url={@to_url}
    />
    """
  end

  attr :name, :string, required: true
  attr :manifest, :map, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1

  # https://vite.dev/guide/backend-integration.html
  defp assets_from_manifest_for_name(%{manifest: manifest, name: name} = assigns) do
    name = Path.relative(name)

    assigns =
      assign(assigns,
        chunk: Map.fetch!(manifest, name),
        imported_chunks: Manifest.imported_chunks(manifest, name)
      )

    ~H"""
    <.reference_for_file :for={css <- @chunk.css} file={css} to_url={@to_url} cache />
    <%= for chunk <- @imported_chunks, css <- chunk.css do %>
      <.reference_for_file file={css} to_url={@to_url} cache />
    <% end %>
    <.reference_for_file file={@chunk.file} to_url={@to_url} cache />
    <.reference_for_file
      :for={chunk <- @imported_chunks}
      file={chunk.file}
      rel="modulepreload"
      to_url={@to_url}
      cache
    />
    """
  end

  attr :file, :string, required: true
  attr :to_url, {:fun, 1}, required: true
  attr :cache, :boolean, default: false
  attr :rest, :global

  defp reference_for_file(assigns) do
    ~H"""
    <script
      :if={Path.extname(@file) == ".js"}
      phx-track-static
      type="module"
      src={@to_url.(cache_enabled_path(@file, @cache))}
      {@rest}
    >
    </script>
    <link
      :if={Path.extname(@file) == ".css"}
      phx-track-static
      rel="stylesheet"
      href={@to_url.(cache_enabled_path(@file, @cache))}
      {@rest}
    />
    """
  end

  defp cache_enabled_path(path, true) do
    "/" |> Path.join(path) |> URI.parse() |> URI.append_query("vsn=d") |> URI.to_string()
  end

  defp cache_enabled_path(path, false) do
    "/" |> Path.join(path) |> URI.parse() |> URI.to_string()
  end

  defp cached_manifest(%{} = manifest) do
    manifest
  end

  defp cached_manifest(manifest) do
    key = {__MODULE__, manifest}

    case :persistent_term.get(key, nil) do
      nil ->
        manifest = Manifest.parse(manifest)
        :persistent_term.put(key, manifest)
        manifest

      manifest ->
        manifest
    end
  end

  @doc """
  Manually clear the cache for a vite manifest source.
  """
  def clear_manifest_cache(manifest) do
    :persistent_term.erase({__MODULE__, manifest})
  end
end
