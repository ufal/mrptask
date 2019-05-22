#!/bin/bash
MRP=/net/work/people/zeman/mrptask
UD24=/net/data/universal-dependencies/2.4
EUD=/lnet/spec/work/people/droganova/Data_for_Enhancer/final_2.4
UDTOOLS=/net/work/people/zeman/unidep/tools
cd $EUD
for i in UD_* ; do
  echo $i
  for j in $i/*.conllu ; do
    echo "  $j"
    $UDTOOLS/conllu_to_text.pl $j > /tmp/ctt.txt
    diff $UD24/`basename $j .conllu`.txt /tmp/ctt.txt
    rm /tmp/ctt.txt
  done
done
