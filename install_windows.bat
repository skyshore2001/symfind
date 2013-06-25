@echo off
set BIN=d:\tempbin
set VIMFILES=D:\vim\vimfiles

:: programs
copy symscan.pl %BIN%\
copy symfind.pl %BIN%\
copy symfind.exe %BIN%\
copy symsvr.pl %BIN%\
copy stags.exe %BIN%\
copy gzip.exe %BIN%\
:: vim plugin
copy symfind.vim %VIMFILES%\plugin\
copy __README__.txt %VIMFILES%\plugin\symfind.txt
pause
