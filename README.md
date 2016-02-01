# symfind

Find symbol or file in your project

## Introduction

Symfind is used to search file or symbol in your project folder. 

It's designed for large project with easy but powerful query, better performance 
and small symbol repository. It's simple, stable, reliable and fast.

It is recommended to work with vim as front-end UI.

## Why I invent this tool

I have worked for a project with 60,000 source files (33,000 for C++, and others 
for java/js/html/scripts) and 2,700,000 symbols (function/macro/class).

On a powerful server (80 CPU Cores with 256G memory), I tried ctags:

	ctags --c-types=+px -R .

and cscope:

	cscope -Rq

First let's have a look at the repo-size and scan time:

	           Repo-size     Scan time
	ctags      566M           126s
	cscope     900M(only C++) 100s
	symfind    27M            44s

Then I want to query symbols that contain "object" and "isvalid":

- Use vim+ctags solution. I input command `:ts /object.*isvalid`, vim throws "tag format error" after 4s. The solution helps locate the symbol with full name, but is very hard to query pattern in a large tag file.
- Use vim+cscope solution. It cannot find the symbol definition, just references. And more, this solution is unstable on large project (often crashes).
- Use symfind. I input command "f object isvalid" and get matched results less than 1s.

So I create this tool that is able to:
- Use simple but powerful query for file or symbol, and it should be very fast via in-memory search.
- Simple, stable and reliable. It must work very well for large project. 
- Provide some specific functions like find macro or variable by value. 
  e.g. you get an error code -5002 and want to query the macro defined for it. Generally you have to use grep or find reference. But symfind should be much easier.

## Install

On Linux, run install_linux and specify your path.

	# sh install_linux.sh

On MS Windows, you need install Perl and then run install_windows.bat.

Symfind use its own "stags" to scan folders. I have pre-compiled binary for
MS Windows (stags.exe) and SuSE Linux 11 (stags). Please find the source code 
of stags and compile on your system.

Note: stags is a branch of ctags with slight change that works better
with Symfind.

## Quick Start

Enter your project folder and run symsvr:

	$ symsvr.pl

It will load symbol repo file "tags.repo.gz" in current folder. If the repo
does not exist, it will call "symscan" tool to scan current folder recursively.

Then start vim/gvim to find files or symbols. Default vim shortcut "\sf" is
installed to open symfind window:

	\sf

Or run this vim command:

	:Symfind

Now input command in the Symfind window. e.g. find some C++ source file which
name contains "hello":

	f .cpp hello

To find C++ function which name contains "main", input:

	s main f

Go to the result by press <Enter> or double-click.

**For detail, install it and view the help doc in vim.**

