#!/bin/sh

BIN=/usr/local/bin
VIMFILES=/usr/share/vim/site

cp ./symscan.pl ./symfind ./symfind.pl ./symsvr.pl ./stags $BIN/
cp ./symfind.vim $VIMFILES/plugin/

