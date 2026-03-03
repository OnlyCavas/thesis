{
  pkgs,
  src ? "./.",
  template ? "templates/chapter.tex",
  filters ? [ ],
  configs ? [ ],
  auto_import ? true,
}:
let
  mergedConfig = pkgs.symlinkJoin {
    name = "includes";
    paths = configs;
  };

  filterArgs = pkgs.lib.concatStringsSep " " (map (f: "--lua-filter=${mergedConfig}/${f}") filters);
in
pkgs.stdenvNoCC.mkDerivation {
  name = "org2tex";
  src = src;
  nativeBuildInputs = [ pkgs.pandoc ];

  buildPhase = ''
    mkdir -p $out

    for file in *.org; do
      if [ -f "$file" ]; then
        basename="''${file%.org}"
        echo "" > combined.org

        if [ "${toString auto_import}" = 1 ]; then
          echo "#+INCLUDE: \"${mergedConfig}/init.org\"" >> combined.org
        fi

        cat $file >> combined.org

        if grep -Fxq '#+OPTIONS: nocompile' combined.org; then
          echo "Skip $file to $out/$basename.tex"
        else
          echo "Converting $file to $out/$basename.tex"
          pandoc combined.org -s \
            ${filterArgs} \
            --top-level-division=chapter \
            --template=${template} \
            -V graphics=false \
            --listings \
            -o "$out/$basename.tex"
        fi
      fi
    done
  '';

  installPhase = ''
    ls -lha $out
  '';
}

# clean_init="$out/header.org"
# sed '/^#+OPTIONS: nocompile$/d' "${mergedConfig}/init.org" > "$clean_init"
#
# cat $clean_init
