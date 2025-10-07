#!/bin/bash

rm -fr build
latexmk -pdf -xelatex -shell-escape -outdir=build -interaction=nonstopmode main.tex
