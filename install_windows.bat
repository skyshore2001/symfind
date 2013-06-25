@echo off
set BIN=d:\tempbin
set VIMFILES=D:\vim\vimfiles

copy symscan.pl %BIN%\
copy symfind.pl %BIN%\
copy symfind.exe %BIN%\
copy symsvr.pl %BIN%\
copy stags.exe %BIN%\
copy gzip.exe %BIN%\
copy symfind.vim %VIMFILES%\plugin\
pause
