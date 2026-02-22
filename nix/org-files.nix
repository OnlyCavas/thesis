{
  pkgs,
  src ? "./.",
  template ? "template/chapter.tex",
}:

pkgs.stdenvNoCC.mkDerivation {
  name = "org2tex";
  src = src;
  nativeBuildInputs = [ pkgs.pandoc ];

  buildPhase = ''
    mkdir -p $out

    for file in *.org; do
      if [ -f "$file" ]; then
        basename="''${file%.org}"
        echo "Converting $file to $out/$basename.tex"
        pandoc "$file" -s \
          --top-level-division=chapter \
          --template=${template} \
          -V graphics=false \
          --listings \
          -o "$out/$basename.tex"
      fi
    done
  '';

  installPhase = ''
    ls -lha $out
  '';
}
