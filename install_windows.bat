@echo off
set BIN=d:\tempbin
set VIMFILES=D:\vim\vimfiles

copy sym*.pl %BIN%\
copy symfind.vim %VIMFILES%\plugin\
pause
