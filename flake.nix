{
  description = "Beat Ecoprove Backend";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            texlive.combined.scheme-full
            zathura
            just
            git-lfs

            # LaTeX LSP and grammar checking
            texlab
            ltex-ls
          ];

          shellHook = ''
            echo "LaTeX environment loaded!"
            echo "Available commands: pdflatex, xelatex, lualatex"
          '';
        };
      });
}
