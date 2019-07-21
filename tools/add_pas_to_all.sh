#!/bin/bash

MRPTASK=/net/work/people/zeman/mrptask
cd $MRPTASK/deepud/data
mkdir -p deep
for i in enhanced/UD_* ; do
  echo $i
  ibase=`basename $i`
  mkdir -p deep/$ibase
  cat $i/*.conllu > deep/$ibase/all.conllu
  ../../tools/add_pas.pl --udpath deep --release http://hdl.handle.net/11234/1-2988 --folder $ibase --file all.conllu > /dev/null 2> deep/$ibase/all.log
  for j in $i/*.conllu ; do
    echo $j
    jbase=`basename $j .conllu`
    ../../tools/add_pas.pl --udpath enhanced --release http://hdl.handle.net/11234/1-2988 --folder $ibase --file $jbase.conllu > deep/$ibase/$jbase.conllup 2> /dev/null
  done
done
