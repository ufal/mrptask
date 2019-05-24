#!/bin/bash
MRP=/net/work/people/zeman/mrptask
UD24=/net/data/universal-dependencies-2.4
EUD=/lnet/spec/work/people/droganova/Data_for_Enhancer/final_2.4
UDTOOLS=/net/work/people/zeman/unidep/tools
cd $UD24
for i in UD_* ; do
  if [ -d $EUD/$i ] ; then
    echo $i
    lcode=$(ls $i | grep ud-test.conllu | perl -e '$x=<STDIN>; $x =~ m/(\S+)-ud-test\.conllu/; print $1;')
    # Some treebanks have training data split to multiple files on Github
    # but there is only one file in the release package.
    # This won't be a problem as long as data in $EUD are based on the official release.
    # Note however that we seem to have forgotten to join the German-HDT training data in UD 2.4.
    for j in $i/*.conllu ; do
      jbase=`basename $j .conllu`
      echo "  $jbase"
      if [ "$jbase" == "cs_pdt-ud-train" ] || [ "$jbase" == "de_hdt-ud-train" ] ; then
        find $EUD/$i -name '*train*.conllu'
        $UDTOOLS/conllu_to_text.pl --lang $lcode $EUD/$i/*train*.conllu > /tmp/ctt.txt
      else
        $UDTOOLS/conllu_to_text.pl --lang $lcode $EUD/$i/$jbase.conllu > /tmp/ctt.txt
      fi
      diff $i/$jbase.txt /tmp/ctt.txt
      rm /tmp/ctt.txt
    done
  fi
done
