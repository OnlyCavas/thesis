export ORG=./Org
export CHAPTERS=./Chapters

pandoc \
    $ORG/$1.org -s \
  --top-level-division=chapter \
  --template=$ORG/templates/chapter.tex \
  -V graphics=false \
  -o $CHAPTERS/$1.tex

sed -i 's/\\label{/\n\\label{/g' $CHAPTERS/$1.tex
sed -i 's/\\pandocbounded{//g; s/}}/}/g' $CHAPTERS/$1.tex
sed -i 's/\\hyperref\[\([^]]*\)\]{\\#\1}/\\ref{\1}/g' $CHAPTERS/$1.tex
sed -i 's/\\begin{longtable}\[\]{@{}\(.*\)@{}$/\\begin{longtable}[]{@{}\1@{}}/g' $CHAPTERS/$1.tex
