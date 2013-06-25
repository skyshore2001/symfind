#!/bin/sh

BIN=~/bin
VIMFILES=~/.vim

CD=`pwd`
ln -sf $CD/symscan.pl $CD/symfind $CD/symfind.pl $CD/symsvr.pl $CD/stags $BIN/
ln -sf $CD/symfind.vim $VIMFILES/plugin/

