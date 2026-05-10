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

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

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

        org2tex =
          {
            dir,
            template ? ./Org/templates/chapter.tex,
            auto_import ? true,
          }:
          import ./nix/org-files.nix {
            inherit pkgs;
            src = dir;
            template = template;
            auto_import = auto_import;
            filters = [
              "org-include.lua"
            ];
            configs = [
              ./Org/config
              ./Org/filters
            ];
          };

        syncTex =
          {
            input,
            texFiles,
            tex ? "main.tex",
          }:
          ''
            CHAPTER_FILE=$(mktemp)

            echo "Translating Org mode to LaTeX"
            for texfile in ${texFiles}/*.tex; do
                cp -v "$texfile" ${input}/

                basename=$(basename "$texfile" .tex)
                echo "\\input{${input}/$basename}" >> "$CHAPTER_FILE"
            done || {
              echo "ERROR: could not copy tex files"
              ls -la ${texFiles} || true
              exit 1
            }

            ${mergeTex {
              input = input;
              tex_file = "$CHAPTER_FILE";
              target_file = tex;
            }}

            trap 'rm -f "$CHAPTER_FILE"' EXIT
          '';

        setConfiguration =
          {

            input,
            tex_file,
            target_file,
          }:
          ''
            CHAPTER_FILE=$(mktemp)

            cat ${tex_file} >> "$CHAPTER_FILE"

            ${mergeTex {
              input = input;
              tex_file = "$CHAPTER_FILE";
              target_file = target_file;
            }}

            trap 'rm -f "$CHAPTER_FILE"' EXIT
          '';

        mergeTex =
          {
            input,
            tex_file,
            target_file,
          }:
          ''
            echo "Applying ${input} Outlet"
            cat ${tex_file}

            ${pkgs.gnused}/bin/sed -i -e "/%<${pkgs.lib.toLower input}-outlet>/ {
                r ${tex_file}
                d
            }" ${target_file}
          '';

      in
      {

        devShells.default =
          let
            buildCharts = pkgs.writeShellScriptBin "build-charts" ''
              mkdir -p Figures/diagrams

              convert_mmd() {
                local f="$1"
                local relpath="''${f#Org/diagrams/}"
                local subdir name outdir outfile

                subdir="$(dirname "$relpath")"
                name="$(basename "$f" .mmd)"
                outdir="Figures/diagrams"

                if [ "$subdir" != "." ]; then
                  outdir="$outdir/$subdir"
                fi

                mkdir -p "$outdir"
                outfile="$outdir/$name.pdf"

                echo "Processing $f -> $outfile..."
                ${pkgs.mermaid-cli}/bin/mmdc \
                  -i "$f" \
                  -o "$outfile" \
                  -c ./mermaid-config.json \
                  -C ./Org/diagrams/style.css \
                  --pdfFit \
                  -w 2400 \
                  -s 2

                pdfcrop "$outfile" "$outfile" 2>/dev/null || true
              }

              for f in Org/diagrams/*.mmd; do
                [ -f "$f" ] && convert_mmd "$f"
              done

              for f in Org/diagrams/*/*.mmd; do
                [ -f "$f" ] && convert_mmd "$f"
              done

              echo "Done! Charts generated in Figures/diagrams/"
            '';

            linuxChrome = if !pkgs.stdenv.isDarwin then "${pkgs.chromium}/bin/chromium" else "";

          in
          pkgs.mkShell {
            packages =
              with pkgs;
              [
                tex
                git-lfs
                texlab
                pandoc
                mermaid-cli
                buildCharts
                liberation_ttf
                source-sans-pro
              ]
              ++ (pkgs.lib.optional (!pkgs.stdenv.isDarwin) pkgs.chromium);

            shellHook = ''
              if [[ "$OSTYPE" == "darwin"* ]]; then
                export PUPPETEER_EXECUTABLE_PATH="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
              else
                export PUPPETEER_EXECUTABLE_PATH="${linuxChrome}"
              fi
              export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
              export FONTCONFIG_FILE=${pkgs.makeFontsConf {
                fontDirectories = [ pkgs.source-sans-pro pkgs.liberation_ttf ];
              }}

              echo "FCUP Thesis Environment Loaded"
              echo "Run 'build-charts' to update your diagrams."
            '';
          };

        packages = rec {
          convertChapters = org2tex {
            dir = ./Org/Chapters;
          };

          convertAppendices = org2tex {
            dir = ./Org/Appendices;
          };

          convertConfig = org2tex {
            dir = ./Org/config;
            auto_import = false;
          };

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
                convertChapters
                convertAppendices
                convertConfig
              ];

              preBuild = ''
                ${syncTex {
                  input = "Chapters";
                  texFiles = convertChapters;
                }}

                ${syncTex {
                  input = "Appendices";
                  texFiles = convertAppendices;
                }}

                cat "${convertConfig}/acronyms.tex"
                ${setConfiguration {
                  input = "Acronyms";
                  target_file = "precontent.tex";
                  tex_file = "${convertConfig}/acronyms.tex";
                }}

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
