#!/bin/sh

BIN=/usr/local/bin
#VIMFILES=/usr/share/vim/site
VIMFILES=$HOME/.vim/

for d in /usr/share/vim/vimfiles/ /usr/share/vim/site; do
	[[ -d $d ]] && VIMFILES=$d && break
done

if [[ `whoami` != "root" ]]; then
	echo "!!! Warning: NOT run as root"
fi

echo -n "binary dir? ($BIN) " ; read opt
[ -n "$opt" ] && BIN=$opt

echo -n "vimfiles dir? ($VIMFILES) " ; read opt
[ -n "$opt" ] && VIMFILES=$opt

# kill current instance
killall symsvr.pl 2>/dev/null && sleep 1
killall symfind 2>/dev/null && sleep 1

EXE="./symscan.pl ./symfind ./symsvr.pl ./stags"

if [[ "$1" == "-u" ]]; then
	cd $BIN && rm -f $EXE
	cd $VIMFILES/plugin && rm -f ./symfind.vim
	cd $VIMFILES/doc && rm -f ./symfind.txt
	exit
fi

mkdir -p $BIN && install $EXE $BIN/
mkdir -p $VIMFILES/plugin && install -m 644 ./symfind.vim $VIMFILES/plugin/
mkdir -p $VIMFILES/doc && install -m 644 ./__README__.txt $VIMFILES/doc/symfind.txt

echo -n "view doc? (=y/n) " ; read opt
[ -n "$opt" ] || opt=y
if [[ $opt == "y" ]]; then
	vim -c "helptags $VIMFILES/doc | h symfind.txt | only"
else
	vim -c "helptags $VIMFILES/doc | q"
	echo done!
fi
