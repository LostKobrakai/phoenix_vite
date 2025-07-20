defmodule PhoenixVite do
  @moduledoc """
  `PhoenixVite` integrates the `vite` built tool with `:phoenix`.
  """

  @doc """
  Returns `:cache_static_manifest_latest` endpoint configuration sourced from a vite manifest file,
  """
  def cache_static_manifest_latest(app)
      when is_atom(app) do
    cache_static_manifest_latest({app, "priv/static/.vite/manifest.json"})
  end

  def cache_static_manifest_latest({app, path})
      when is_atom(app) and is_binary(path) do
    {app, path}
    |> PhoenixVite.Manifest.parse()
    |> PhoenixVite.Manifest.cache_static_manifest_latest()
  end
end
