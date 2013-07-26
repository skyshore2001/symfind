#!/bin/sh

BIN=/usr/local/bin
VIMFILES=/usr/share/vim/site

echo -n "binary dir? ($BIN) " ; read opt
[ -n "$opt" ] && BIN=$opt

echo -n "vimfiles dir? ($VIMFILES) " ; read opt
[ -n "$opt" ] && VIMFILES=$opt

# kill current instance
killall symsvr.pl 2>/dev/null && sleep 1
killall symfind 2>/dev/null && sleep 1

cp ./symscan.pl ./symfind ./symfind.pl ./symsvr.pl ./stags $BIN/
cp ./symfind.vim $VIMFILES/plugin/
cp ./__README__.txt $VIMFILES/doc/symfind.txt

echo -n "view doc? (=y/n) " ; read opt
[ -n "$opt" ] || opt=y
if [[ $opt == "y" ]]; then
	vim -c "helptags $VIMFILES/doc | h symfind.txt | only"
else
	vim -c "helptags $VIMFILES/doc | q"
	echo done!
fi
