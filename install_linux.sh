#!/bin/sh

BIN=/usr/local/bin
VIMFILES=/usr/share/vim/site

echo -n "binary dir? ($BIN) " ; read opt
[ -n $opt ] && BIN=$opt

echo -n "vimfiles dir? ($VIMFILES) " ; read opt
[ -n $opt ] && VIMFILES=$opt

cp ./symscan.pl ./symfind ./symfind.pl ./symsvr.pl ./stags $BIN/
cp ./symfind.vim $VIMFILES/plugin/
cp ./__README__.txt $VIMFILES/doc/symfind.txt
echo done!
