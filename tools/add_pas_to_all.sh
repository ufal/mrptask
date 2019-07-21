#!/bin/bash

MRPTASK=/net/work/people/zeman/mrptask
cd $MRPTASK/deepud/data
mkdir -p deep
for i in enhanced/UD_* ; do
  ibase=`basename $i`
  mkdir -p deep/$ibase
  for j in $i/*.conllu ; do
    echo $j
    jbase=`basename $j .conllu`
    ../../tools/add_pas.pl --udpath enhanced --release http://hdl.handle.net/11234/1-2988 --folder $ibase --file $jbase.conllu > deep/$ibase/$jbase.conllup 2> deep/$ibase/$jbase.log
  done
done
