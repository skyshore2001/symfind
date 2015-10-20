@echo off

mklink a1 a2 1>NUL 2>NUL
if errorlevel 1 (
	echo *** Error: Please run as admin.
	goto :END
)
del a1

setlocal

set script=%0
:: add ""
if not %script:~0,1% == ^" (
	set script="%script%"
)

set ADD_TO_PATH=
set SYMFIND_HOME=
set VIMFILES=D:\vim\vimfiles
set GVIM=gvim

set TMP_BAT=%tmp%\1.bat
:: reg query MUST run in c:
( pushd c: && reg query HKEY_LOCAL_MACHINE\SOFTWARE\Vim\Gvim /v path 2>NUL && popd ) | perl -x %script% > %TMP_BAT%
if errorlevel 1 (
	echo *** Error: Perl is required.
	goto :END
)
call %TMP_BAT%

:: set SYMFIND_HOME
:: set VIMFILES
:: set GVIM
:: pause
:: goto :EOF

set opt=
set /p opt="vimfiles dir? (%VIMFILES%) "
if not "%opt%"=="" set VIMFILES=%opt%

setx SYMFIND_HOME %SYMFIND_HOME% >NUL
if "%ADD_TO_PATH%" == "1" (
	setx path "%path%;%%SYMFIND_HOME%%" >NUL
)

:: vim plugin
pushd "%SYMFIND_HOME%"
copy symfind.vim %VIMFILES%\plugin\
copy __README__.txt %VIMFILES%\doc\symfind.txt

set opt=y
set /p opt="view doc? (=y/n) "
if "%opt%"=="y" (
	%GVIM% -c "helptags %VIMFILES%\doc | h symfind.txt | only"
) else (
	%GVIM% -c "helptags %VIMFILES%\doc | q"
	echo done.
)

:END
pause
goto :EOF

################# perl cmd {{{
#!perl -n
use File::Basename;
use Cwd;

chdir(dirname($0));
$pwd = getcwd();
$pwd =~ s+/+\\+g;
print "set SYMFIND_HOME=" . $pwd . "\n";
if (index($ENV{PATH}, "SYMFIND_HOME") < 0) {
	print "set ADD_TO_PATH=1\n";
}

while (<>) {
	/REG_SZ\s*(.*)/ && do {
		$f = $1;
		$d = dirname(dirname($f));
		print "set GVIM=\"$f\"\n";
		print "set VIMFILES=\"$d\\vimfiles\"\n";
	}
}

#}}}
# vim: set foldmethod=marker :

