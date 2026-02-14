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

        utils = {
          stripText =
            name: if nixpkgs.lib.hasSuffix ".tex" name then nixpkgs.lib.removeSuffix ".tex" name else name;

          formatDate =
            dateStr:
            let
              dateOnly = builtins.substring 0 8 (toString dateStr);
              year = builtins.substring 0 4 dateOnly;
              month = builtins.substring 4 2 dateOnly;
              day = builtins.substring 6 2 dateOnly;
            in
            "${year}_${month}_${day}";

          open = if pkgs.stdenv.isDarwin then "/usr/bin/open" else "${pkgs.xdg-utils}/bin/xdg-open";
          echo = "${pkgs.coreutils}/bin/echo";
          nix = "${pkgs.nix}/bin/nix";
        };

        mkThesis = import (./nix/mkPdf.nix) {
          inherit
            self
            pkgs
            tex
            utils
            ;
        };

        org2tex = import ./nix/org-files.nix {
          inherit pkgs;
          src = ./Org;
        };

      in
      {

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            tex
            git-lfs
            texlab
            ltex-ls
            pandoc
          ];

          shellHook = ''
            echo "LaTeX environment loaded!"
            echo "latexmk version: $(latexmk --version)"
            echo "Commands: nix run, nix run .#header"
            echo ""
            echo "          nix run -> to open or compile to pdf"
            echo "          nix run .#compile -> compile to pdf"
            echo "          nix run .#header compile only header"
            echo "" '';
        };

        packages = rec {
          convert = org2tex;

          compile-header = mkThesis {
            name = "header";
            entryMainTex = "main.tex";
            build_src = ./Front;
            outputName = "header.pdf";
          };

          default =
            let

              base = mkThesis {
                entryMainTex = "main.tex";
                build_src = ./.;
              };

            in

            base.overrideAttrs (old: {
              buildInputs = old.buildInputs or [ ] ++ [
                compile-header
                convert
              ];

              preBuild = ''
                echo "Translating Org mode to LaTeX"
                for texfile in ${convert}/*.tex; do
                    cp -v "$texfile" Chapters/
                  done || {
                    echo "ERROR: could not copy tex files"
                    ls -la ${convert} || true
                    exit 1
                  }

                  echo "Preparing header PDF ..."
                  cp -v ${compile-header}/header.pdf Front/main.pdf || {
                    echo "ERROR: could not copy header.pdf"
                    ls -la ${compile-header} || true
                    exit 1
                  } '';
            });

        };

        apps = {
          default = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "" ''
                PDF_PATH="result/draft_${utils.formatDate self.lastModifiedDate}.pdf"

                if [ -f "$PDF_PATH" ]; then
                  ${utils.echo} "Opening existing $PDF_PATH..."
                  ${utils.open} "$PDF_PATH"
                else
                  ${utils.echo} "PDF not found, building..."
                  ${utils.nix} run .#compile
                fi
              ''
            );
          };

          compile = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "build-thesis" ''
                ${utils.echo} "Building thesis..."
                ${utils.nix} build
                ${utils.echo} "Opening PDF..."

                ${utils.open} "result/draft_${utils.formatDate self.lastModifiedDate}.pdf"
              ''
            );
          };

          header = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "build-and-open-header" ''
                ${utils.echo} "Building header..."
                ${utils.nix} build .#compile-header
                ${utils.echo} "Opening PDF..."

                ${utils.open} "result/header.pdf"
              ''
            );
          };
        };
      }
    );
}
