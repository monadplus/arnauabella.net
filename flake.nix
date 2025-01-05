{
  description = "A flake for building arnauabella.net";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.apollo = { url = "github:not-matthias/apollo"; flake = false; };
  # inputs.flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";

  outputs = { self, nixpkgs, flake-utils, apollo }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        themeName = ((builtins.fromTOML (builtins.readFile "${apollo}/theme.toml")).name);
      in
      {
        packages.website = pkgs.stdenv.mkDerivation {
          name = "static-website";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ pkgs.zola ];
          configurePhase = ''
            mkdir -p "themes/${themeName}"
            cp -r ${apollo}/* "themes/${themeName}"
          '';
          buildPhase = "zola build";
          installPhase = "cp -r public $out";
        };
        defaultPackage = self.packages.${system}.website;
        devShell = pkgs.mkShell {
          packages = with pkgs; [
            zola
          ];
          shellHook = ''
            mkdir -p themes
            ln -sn "${apollo}" "themes/${themeName}"
          '';
        };
      }
    );
}
