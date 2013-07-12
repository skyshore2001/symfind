@echo off
setlocal
set BIN=d:\tempbin
set VIMFILES=D:\vim\vimfiles

set opt=
set /p opt="binary dir? (%BIN%) "
if not "%opt%"=="" set BIN=%opt%

set opt=
set /p opt="vimfiles dir? (%VIMFILES%) "
if not "%opt%"=="" set VIMFILES=%opt%

:: programs
copy symscan.pl %BIN%\
copy symfind.pl %BIN%\
copy symfind.exe %BIN%\
copy symsvr.pl %BIN%\
copy stags.exe %BIN%\
copy gzip.exe %BIN%\
:: vim plugin
copy symfind.vim %VIMFILES%\plugin\
copy __README__.txt %VIMFILES%\doc\symfind.txt
pause
