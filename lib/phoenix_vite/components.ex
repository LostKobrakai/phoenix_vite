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

  To download lazily loaded chunks in the background once the page has
  loaded, set `prefetch`:

      <PhoenixVite.Components.assets
        names={["js/app.js"]}
        manifest={{:my_app, "priv/static/.vite/manifest.json"}}
        dev_server={PhoenixVite.Components.has_vite_watcher?(MyAppWeb.Endpoint)}
        prefetch={[concurrency: 3]}
      />

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

  ## Prefetching

  `prefetch` downloads lazily loaded chunks after the page loads, so they are
  already cached when needed. It does not apply on the dev server.

    * `prefetch` - download them all at once
    * `prefetch={[concurrency: 3]}` - download three at a time
    * `prefetch={[event: "app:ready"]}` - wait for this `window` event
      instead of `load`

  `nonce` is set on every script and link rendered, the prefetch script
  included, for a content security policy.
  """
  attr :names, :list, required: true
  attr :manifest, :any, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1
  attr :dev_server, :boolean, default: false
  attr :crossorigin, :any, default: false
  attr :nonce, :string, default: nil

  attr :prefetch, :any,
    default: false,
    doc: "`true` or a keyword list of `:concurrency` and `:event`"

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
  attr :crossorigin, :any, default: false
  attr :nonce, :string, default: nil
  attr :prefetch, :any, default: false

  # https://vite.dev/guide/backend-integration.html
  def assets_from_dev_server(assigns) do
    ~H"""
    <script
      phx-track-static
      crossorigin={@crossorigin}
      nonce={@nonce}
      type="module"
      src={@to_url.("/@vite/client")}
    >
    </script>
    <.reference_for_file
      :for={name <- @names}
      file={name}
      to_url={@to_url}
      crossorigin={@crossorigin}
      nonce={@nonce}
    />
    """
  end

  @doc """
  Asset references of vite manifest to be placed into the `<head />` of a html page.

  Caches manifests at runtime when refernces require parsing per provided source.
  """
  attr :names, :list, required: true
  attr :manifest, :any, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1
  attr :crossorigin, :any, default: false
  attr :nonce, :string, default: nil
  attr :prefetch, :any, default: false

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
      crossorigin={@crossorigin}
      nonce={@nonce}
    />
    <.prefetch
      :if={@prefetch}
      names={@names}
      manifest={@manifest}
      to_url={@to_url}
      crossorigin={@crossorigin}
      nonce={@nonce}
      options={if @prefetch == true, do: [], else: @prefetch}
    />
    """
  end

  attr :name, :string, required: true
  attr :manifest, :map, required: true
  attr :to_url, {:fun, 1}, default: &Function.identity/1
  attr :crossorigin, :any, default: false
  attr :nonce, :string, default: nil

  # https://vite.dev/guide/backend-integration.html
  defp assets_from_manifest_for_name(%{manifest: manifest, name: name} = assigns) do
    name = Path.relative(name)

    assigns =
      assign(assigns,
        chunk: Map.fetch!(manifest, name),
        imported_chunks: Manifest.imported_chunks(manifest, name)
      )

    ~H"""
    <.reference_for_file
      :for={css <- @chunk.css}
      file={css}
      to_url={@to_url}
      crossorigin={@crossorigin}
      nonce={@nonce}
    />
    <%= for chunk <- @imported_chunks, css <- chunk.css do %>
      <.reference_for_file file={css} to_url={@to_url} crossorigin={@crossorigin} nonce={@nonce} />
    <% end %>
    <.reference_for_file
      file={@chunk.file}
      to_url={@to_url}
      crossorigin={@crossorigin}
      nonce={@nonce}
    />
    <.reference_for_file
      :for={chunk <- @imported_chunks}
      file={chunk.file}
      rel="modulepreload"
      to_url={@to_url}
      crossorigin={@crossorigin}
      nonce={@nonce}
    />
    """
  end

  attr :names, :list, required: true
  attr :manifest, :map, required: true
  attr :to_url, {:fun, 1}, required: true
  attr :crossorigin, :any, required: true
  attr :nonce, :string, required: true
  attr :options, :list, required: true

  defp prefetch(%{manifest: manifest, options: options} = assigns) do
    options = Keyword.validate!(options, concurrency: nil, event: "load")

    assets =
      manifest
      |> Manifest.prefetched_files(assigns.names)
      |> Enum.map(&prefetch_attributes(&1, assigns))

    assigns =
      assign(assigns,
        prefetch?: assets != [],
        assets: script_json(assets),
        concurrency: script_json(options[:concurrency]),
        event: script_json(options[:event])
      )

    ~H"""
    <script :if={@prefetch?} nonce={@nonce}>
      (() => {
        const queue = <%= @assets %>
        function next() {
          const asset = queue.shift()
          if (!asset) return
          const link = document.createElement("link")
          for (const name in asset) link.setAttribute(name, asset[name])
          link.onload = link.onerror = next
          document.head.append(link)
        }
        window.addEventListener(<%= @event %>, () => setTimeout(() => {
          for (let i = <%= @concurrency %> || queue.length; i > 0; i--) next()
        }))
      })()
    </script>
    """
  end

  # Raw, as HTML escaping would break the JS, with "<" escaped so a value cannot close the script.
  defp script_json(value) do
    value |> JSON.encode!() |> String.replace("<", "\\u003c") |> Phoenix.HTML.raw()
  end

  defp prefetch_attributes(file, %{to_url: to_url, crossorigin: crossorigin}) do
    as = if Path.extname(file) == ".css", do: "style", else: "script"

    attributes = %{
      rel: "prefetch",
      fetchpriority: "low",
      as: as,
      href: to_url.(Path.join("/", file))
    }

    cond do
      !crossorigin -> attributes
      crossorigin == true -> Map.put(attributes, :crossorigin, "")
      true -> Map.put(attributes, :crossorigin, crossorigin)
    end
  end

  attr :file, :string, required: true
  attr :to_url, {:fun, 1}, required: true
  attr :crossorigin, :any, default: false
  attr :nonce, :string, default: nil
  attr :rest, :global, include: ~w(rel)

  defp reference_for_file(assigns) do
    ~H"""
    <script
      :if={Path.extname(@file) in [".js", ".ts", ".jsx", ".tsx"]}
      phx-track-static
      type="module"
      crossorigin={@crossorigin}
      nonce={@nonce}
      src={@to_url.(Path.join("/", @file))}
      {@rest}
    >
    </script>
    <link
      :if={Path.extname(@file) == ".css"}
      phx-track-static
      rel="stylesheet"
      crossorigin={@crossorigin}
      nonce={@nonce}
      href={@to_url.(Path.join("/", @file))}
      {@rest}
    />
    """
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
