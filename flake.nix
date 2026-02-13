{
  description = "Strengthening Torrent File-Sharing Protocol with the Cryptographic Hardware Solutions and Onion Network";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        tex = pkgs.texlive.withPackages (
          ps: with ps; [
            scheme-full
            latexmk
          ]
        );
      in
      rec {

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            tex
            zathura
            just
            git-lfs
            texlab
            ltex-ls
          ];

          shellHook = ''
            echo "LaTeX + just environment loaded!"
            echo "latexmk version: $(latexmk --version)"
            echo "Commands: just build, just rebuild, just open, just clean"
            echo "Final PDF: nix build .#build-draft && open result/thesis.pdf"
          '';
        };

        packages.build-draft = pkgs.stdenvNoCC.mkDerivation {
          pname = "draft";
          version = "2026-02";

          src = ./.;

          nativeBuildInputs = [
            tex
            pkgs.git
            pkgs.perl
          ];

          preBuild = ''
            git lfs install --local || true
            git lfs pull || true
          '';

          buildPhase = ''
            runHook preBuild

            export XDG_CACHE_HOME=$(mktemp -d -t xdg-cache.XXXXXX)
            mkdir -p $XDG_CACHE_HOME/fontconfig

            export TEXMFVAR=$(mktemp -d -t texmfvar.XXXXXX)
            export TEXMFCONFIG=$(mktemp -d -t texmfconfig.XXXXXX)
            export TEXMFHOME=$(mktemp -d -t texmfhome.XXXXXX)
            export TEXMFCACHE=$TEXMFVAR

            unset TEXMFCNF || true

            latexmk \
              -pdf \
              -xelatex \
              -shell-escape \
              -interaction=nonstopmode \
              -file-line-error \
              -f \
              -outdir=build \
              main.tex || { cat build/main.log || true; exit 1; }

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp build/main.pdf $out/thesis.pdf || { echo "PDF missing!"; exit 1; }
            runHook postInstall
          '';

          doCheck = true;
          checkPhase = ''
            [ -f build/main.pdf ] || { echo "PDF missing!"; exit 1; }
          '';
        };

        packages.default = packages.build-draft;
      }
    );
}
