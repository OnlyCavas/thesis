{
  pkgs,
  src ? "./.",
}:

pkgs.stdenvNoCC.mkDerivation {
  name = "convert-org-files";
  version = "2.0";
  src = src;

  nativeBuildInputs = [ pkgs.pandoc ];

  buildInputs = [ pkgs.pandoc ];

  buildPhase = ''
    mkdir -p $out

    for file in *.org; do
      if [ -f "$file" ]; then
        basename="''${file%.org}"
        echo "Converting $file to $out/$basename.tex"
        pandoc "$file" -s \
          --top-level-division=chapter \
          --template=templates/chapter.tex \
          -V graphics=false \
          -o "$out/$basename.tex"
      fi
    done
  '';

  installPhase = ''
    ls -lha $out
  '';
}
