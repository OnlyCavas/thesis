{
  self,
  pkgs,
  tex,
  utils,
}:

{
  name ? "draft",
  version ? utils.formatDate self.lastModifiedDate,
  entryMainTex ? "main.tex",
  extraBuildArgs ? "-pdf -xelatex",
  extraLatexmkFlags ? "",
  outputName ? "${name}_${version}.pdf",
  build_src ? "./.",
}@args:

let
  entryMainPDF = utils.stripText entryMainTex;
in
pkgs.stdenvNoCC.mkDerivation (
  args
  // {
    pname = name;
    version = version;

    src = build_src;

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
        ${extraBuildArgs} \
        ${extraLatexmkFlags} \
        -shell-escape \
        -interaction=nonstopmode \
        -file-line-error \
        -f \
        -outdir=build \
        ${entryMainTex} || { cat build/${builtins.baseNameOf entryMainPDF}.log || true; exit 1; }

      ls -la build/
      cat build/main.acn || true
      cat build/main.acr || true

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp build/${builtins.baseNameOf entryMainPDF}.pdf $out/${outputName} || { echo "PDF missing!"; exit 1; }
      runHook postInstall
    '';

    doCheck = true;
    checkPhase = ''
      [ -f build/${builtins.baseNameOf entryMainPDF}.pdf ] || { echo "PDF missing!"; exit 1; }
    '';
  }
)
