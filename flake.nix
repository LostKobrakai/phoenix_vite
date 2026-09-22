{
  description = "PhoenixVite development environment";

  inputs = {
    # Stable-enough rolling channel pinned by flake.lock.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Keep the development shell portable across common Linux and macOS targets.
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beam = pkgs.beam.packages.erlang_28;
        elixir = beam.elixir_1_19;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            beam.erlang
            elixir
            pkgs.git
            pkgs.nodejs_24
          ];

          shellHook = ''
            export LANG=C.UTF-8
            export LANGUAGE=C
            export LC_ALL=C.UTF-8
            export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
            export MIX_HOME="$PWD/.nix/mix"
            export HEX_HOME="$PWD/.nix/hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME"
          '';
        };
      }
    );
}
