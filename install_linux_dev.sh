#!/bin/sh

BIN=~/bin
VIMFILES=~/.vim

[ -d $BIN ] && mkdir $BIN
CD=`pwd`
ln -sf $CD/symscan.pl $CD/symfind $CD/symsvr.pl $CD/stags $BIN/
ln -sf $CD/symfind.vim $VIMFILES/plugin/

