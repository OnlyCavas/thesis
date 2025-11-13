# Default target
default: compile

# Run everything inside Nix dev shell
compile:
    nix develop --command just rebuild

# Fix repo
fix-repo:
  git lfs install --local
  git lfs pull

# Build PDF using latexmk and XeLaTeX
build:
    latexmk -pdf -xelatex -shell-escape -outdir=build -interaction=nonstopmode -f main.tex 2>/dev/null || true
    cp build/main.pdf .

# Clean auxiliary files
clean:
    latexmk -c -outdir=build

# Full clean (including build directory)
clean-all:
    rm -rf build main.pdf

# Open PDF (using zathura if available)
open:
    zathura main.pdf &

# Rebuild from scratch
rebuild: fix-repo clean build open
