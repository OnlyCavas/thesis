((latex-mode
  . ((TeX-command-default . "Generate PDF")
     (TeX-engine . xetex)
     (TeX-PDF-mode . t)
     (TeX-save-query . nil)
     (TeX-show-compilation . t)
     (TeX-command-list
      . (("LatexMk"
          "latexmk -pdf -xelatex -shell-escape -outdir=build -interaction=nonstopmode -f %s && latexmk -c -outdir=build && cp build/main.pdf ."
          TeX-run-TeX nil t
          :help "Run latexmk on file"))))))
