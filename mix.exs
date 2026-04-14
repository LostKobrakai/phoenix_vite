defmodule PhoenixVite.MixProject do
  use Mix.Project

  def project do
    [
      name: "Phoenix Vite",
      source_url: "https://github.com/LostKobrakai/phoenix_vite",
      app: :phoenix_vite,
      version: "0.4.2",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:bun, "~> 1.5 and >= 1.5.1", optional: true, runtime: false},
      {:igniter, "~> 0.6", optional: true},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp aliases do
    colored_mix = "elixir --erl \"-elixir\\ ansi_enabled\\ true\" -S mix"

    [
      "hex.publish": ["cmd npm run build", "hex.publish"],
      checks: [
        "cmd #{colored_mix} deps.unlock --check-unused",
        "cmd #{colored_mix} xref graph --format cycles --label compile-connected --fail-above 0",
        "cmd #{colored_mix} format --check-formatted",
        "cmd #{colored_mix} compile --force --warnings-as-errors",
        "cmd #{colored_mix} dialyzer#{if System.get_env("CI"), do: " --format github"}"
      ]
    ]
  end

  defp description() do
    "`PhoenixVite` integrates the `vite` built tool with `:phoenix`."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib priv .formatter.exs mix.exs package.json README* LICENSE* CHANGELOG*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/LostKobrakai/phoenix_vite"}
    ]
  end
end
