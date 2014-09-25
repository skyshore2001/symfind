*symfind.txt*	For Vim version 7.3.  Last change: 2013 June 20

	    Symfind - Locate files and symbols for large project
		    Liang, Jian - 2013/5

1. Introduction						|sf-intro|
2. Install						|sf-install|
3. Quick Start						|:Symfind|
4. Use Symfind						|sf-using|
	4.1 Repository					|sf-repo|
	4.2 Query syntax				|sf-query|
	4.3 Grep reference 				|sf-grep|
	4.4 Options					|sf-options|
5. Use Symsvr and vim plugin				|sf-symsvr|
6. Contact me						|sf-contact|
7. FAQ							|sf-faq|

==============================================================================
1. Introduction						*sf-intro*

Symfind is used to search file or symbol in your project folder. 

It's designed for large project with easy but powerful query, better performance 
and small symbol repository. It's simple, stable, reliable and fast.

It is recommended to work with vim as front-end UI.

Comparison with other tools~

I am working for a project with 60,000 source files (33,000 for C++, and others 
for java/js/html/scripts) and 2,700,000 symbols (function/macro/class).

On a powerful server (80 CPU Cores with 256G memory), I tried ctags: >
	ctags --c-types=+px -R .
and cscope: >
	cscope -Rq

With tags I can locate symbol quickly in vim using full name, but it 
turns very hard if I want to query symbols that contain "object" and "isvalid". 
More critical, it may have bug on my huge project that vim throw "tag format error"
when I search ":ts /object.*isvalid".

Cscope is powerful to find cross-reference, but the query I want is not available 
as well. And I have to say the tool is unstable for my project. 

Compare: 
	   Repo-size    Scan time     Query symbols contains "object" and "isvalid"

ctags      566M         126s          vim cmd ":ts /object.*isvalid"
				      throw "tag format error" after 4s.
cscope     900M(only C++) 100s        cannot find the definition, just find reference

symfind    27M          44s           symfind cmd "f object isvalid"
				      get matched results less than 1s.

- Symfind use simple but powerful query for file or symbol (|sf-query|)
  And it is very fast as it performs in-memory search.

- Simple, stable and reliable
  It works very well for large project. 

- Specific functions like find macro or variable by value
  e.g. you get an error code -5002 and want to query the macro defined for it.
  Other tools have to use grep. 

==============================================================================
2. Install							*sf-install*

On Linux, run install_linux and specify your path. >
	# sh install_linux.sh

On MS Windows, you need install Perl and then run install_windows.bat.

Symfind use its own "stags" to scan folders. I have pre-compiled binary for
MS Windows (stags.exe) and SuSE Linux 11 (stags). Please find the source code 
of stags and compile on your system.

Note: stags is a branch of ctags with slight change that works better
with Symfind.

==============================================================================
3. Quick Start 						*:Symfind*

Enter your project folder and run symsvr: >
	$ symsvr.pl

It will load symbol repo file "tags.repo.gz" in current folder. If the repo
does not exist, it will call "symscan" tool to scan current folder recursively.

Then start vim/gvim to find files or symbols. Default vim shortcut "\sf" is
installed to open symfind window: >

	\sf

Or run this vim command: >

	:Symfind

Now input command in the Symfind window. e.g. find some C++ source file which
name contains "hello": >
	f .cpp hello

To find C++ function which name contains "main", input: >
	s main f
("f" means type is function, refer to |sf-query| for detail.)

Go to the result by press <Enter> or double-click.

These shortcuts are set to find file or symbol under cursor: >
	\g]  or \<c-]>
	        - search symbol under cursor in symfind
	\gf     - search file under cursor in symfind

How to remember:
As |g]| and |gf| are default vim shortcut for locate a symbol (tag) and file,
here I just add the <leader> char in front of them.

==============================================================================
4. Use Symfind							*sf-using*

Key components: >
	symscan.pl (code scanner, generates repo-file)
	symfind (search engine, command-line interface)
	symsvr.pl (search engine server, TCP/IP interface, a wrapper of symfind)
	symfind.vim (enable vim as client to work with symsvr.pl)

To use symfind, first use symscan to generate symbol repository for your project 
folder, then use symsvr to load the repo: >
	$ symscan.pl $SBO_BASE/Source
	$ symsvr.pl

The default repository name is "tags.repo.gz". You can specify the repo name 
with option "-o", e.g. >
	$ symscan.pl $SBO_BASE/Source -o b1

It will create repository "b1.repo.gz". To update this repository: >
	$ symscan.pl b1.repo.gz

Run symsvr to work with vim: >
	$ symsvr.pl b1.repo.gz

Alternatively (often for debug purpose), you can run symfind for command-line UI: >
	$ symfind b1.repo.gz

It's the command-line interface: >
	> ?
	(show command help)
	> f string cpp
	(find file name that has "string" and "cpp", case-insensitive search)
	> s Sbo string
	(find symbol name that has "Sbo" - match case as there's upper letter,
	 and contains "string" - ignore case as there's no upper letter.)
	> go 2
	(go to the 2nd location in the result list, by default open file using vi)
	> n
	(go to the next location)
	> N
	(go to the previous location)
	> q
	(quit)
	
4.1 Symfind Repository file (repo-file) 				*sf-repo*

A repo-file (e.g. tags.repo.gz) is a text file compressed using gzip. It contains
one or more repository. Each repository is for one folder. e.g. >
	$ symscan.pl /home/data/dir1 /home/data/dir2

The generated repo-file (tags.repo.gz) actually contains 2 repos respectively 
for the 2 folders.

To update the repo-file actually re-scan the original 2 folders: >
	$ symscan.pl tags.repo.gz

To update and add new folder to the repository: >
	$ symscan.pl tags.repo.gz /home/data/dir3

*Note*
you can rename the output repo-file. But don't remove the extension name ".gz".

Pattern for scanning file~
2 variables are available for you to customize the scanning.
IGNORE_PAT 
	(default value = '*.o;*.obj;*.d;.*')
	Don't record such files into repo.
TAGSCAN_PAT 
	(default value = '*.c;*.cpp;*.h;*.hpp;*.cc;*.mak;*.cs;*.java;*.s')
	Scan such files for symbols.

(TODO: set envvar to customize)

Load and use multiple repo-files ~
symfind simply supports more than 1 repositories: >
	$ symfind 1.repo.gz 2.repo.gz 3.repo.gz

or use "add" command after symfind starts: >
	$ symfind 1.repo.gz
	(now enter symfind command-line interface)
	> add 2.repo.gz 3.repo.gz
	(add 1 or more repo-files)

==============================================================================
4.2 Query syntax						*sf-query*

Query by words separated by space; Word that contains captain letter performs 
case-sensitive search, or else case-insensitive: >
	> s foo Bar
	(symbols contain "foo" (case-insensitive) and "Bar" (case-sensitive))

Start-with/end-with is suppported by "^" and "$" (like regexp but limited): >
	> f ^Sbo .cpp$
	(files start with "Sbo" and end with ".cpp")

(Perl version *symfind.pl* uses perl-style Regexp. Thus, "." is a magic char in
 Regexp, you should use "\.cpp$" instead.)

Search in path: xxx/ ~

For files, pattern that ends with "/" means search folder name: >
	> f ace thirdparty/
	(files that contain "ace" and in a folder that contains "thirdparty")

For symbols, pattern that ends with "/" means search file name or folder name: >
	> s ::CreateObject$ f .h/ source/
	(member function "CreateObject" defined in header files (.h/) and under folder "source")

Search symbol kind~

For symbols, the result lists symbol names and kinds. To filter the result by
kind, use the first character of the kind name, e.g. "c" for "class": >
	> s string
	(list symbols match "string", there are kinds of "prototype", "class",
	 "function", "macro" and "member")
	> s string c
	(just find "class")

If it cannot filter kinds with the first-char, use the 2nd (or 3rd...): >
	> s string m
	(find "member" or "macro")
	> s string m e
	(find "member" - match 2 chars of kind)
	> s string m e m
	(find "member")

Search symbol value: #xxx ~

For symbols, pattern that starts with "#" means search in values. E.g. you get
a error code -5002 and want to see if some macro is defined by this value: >
	> s #-5002

You can composite all the features. e.g. >
	> s ^dbm #-5002 m
	(start with "dbm", value contains "-5002" and is a "macro")

2-choices: symfind and symfind.pl ~

They have almost the same functions. symfind is recommended as it's re-written 
using C++ with speed and memory optimization.
e.g. load 65322 files, 2022655 symbols (19M repo-file): symfind.pl uses 8.1s 
and 1.1G memory; symfind uses 0.6s and 180M memory.  For a full symbols search 
with 2 words (e.g. "hello world"), symfind.pl costs 2.8s, and symfind costs 0.4s.

Note: by default symsvr.pl uses symfind for the search engine. To use
symfind.pl, set envvar SYMFIND, e.g. (on Linux) >
	$ SYMFIND=symfind.pl symsvr.pl 1.repo.gz

==============================================================================
4.3 Grep reference 						*sf-grep*

Symfind works with GNU grep to find symbol reference. e.g. >
	> g main
	(search "main" under the repository root dir, recursively)
	> g main *.cpp *.h
	(search "main" in .cpp or .h files)
	> g main -*.java
	(search "main" in files except *.java)

Search is case-insensitive unless your pattern contains uppercase letters. >
	> g Main *.java
	(search "Main", case-sensitive)

The search pattern is directly used by grep. You can use grep option before
the pattern: >
	> g -w main
	(-w: match the whole word)
	> g -F main
	(-F: pattern is fixed-string)

On Windows, it's recommended to run Symfind under Mingw to work with correct
POSIX programs like grep/tee.

==============================================================================
4.4 Options 							*sf-options*

Change max result items~

By default 25 items are listed in the result. To change it: >
	> max 50

Change editor~

By default "vi" is used to open file, to change it: >
	> editor
	(view the current editor)

	> editor gvim
	(change editor)

Change root~

Root is the top-level folder name when you scan your project. e.g. >
	$ symscan.pl /mnt/data/depot/sbo
the root is "/mnt/data/depot/sbo". If you moved it to another path, e.g.
"/mnt/data/depot2/sbo", then you can set option to reuse the repo-file: >
	> root /mnt/data/depot/sbo=/mnt/data/depot2/sbo

OR simply >
	> root depot=depot2

The result folder name will be checked and replaced if neccessary.

==============================================================================
5. Use Symsvr and vim plugin					*sf-symsvr*

*symsvr.pl* is a program that enables symfind to be a symbol server. By
default, it use TCP port 20000 - instance 0 (port=instance_no+20000). If you
want to use another instance/port: >
	$ symsvr.pl 1.repo.gz &
	  (TCP/20000)
	$ symsvr.pl 2.repo.gz :1 &
	  (TCP/20001)

The vim plugin~

After the server starts, you can start vim to search. Use :Symfind command to 
open the search window. >
	:Symfind
or use the default mapped shortcut: >
	\sf

If you use instance 1, the command is like this: >
	:Symfind :1
or >
	\1sf

Symsvr as a client~

For test, you can directly search in shell by "symsvr.pl -c": >
	$ symsvr.pl -c "f sbo string"
	  (find file)
	$ symsvr.pl -c "s hello world" :1
	  (find symbol using instance 1 - port 20001)

==============================================================================
6. Contact me						*sf-contact*

Liang, Jian - skyshore@gmail.com

Thanks to the following softwares that give my ideas: >

	ctags 
	vgdb
	Visual AssistX

==============================================================================
7. FAQ       						*sf-faq*

Q: Why can not such symbol be found (in apache library, util_cookie.h): >
	AP_DECLARE(apr_status_t) ap_cookie_write(request_rec * r, const char *name,
                                         const char *val, const char *attrs,
                                         long maxage, ...) AP_FN_ATTR_SENTINEL;

A: The macro AP_DECLARE and AP_FN_ATTR_SENTINEL cannot be recongnized by
etags that is based on ctags and used by symscan program. You can use ctags 
option -I to solve it, e.g. define the option in environment variable: >

	$ export CTAGS=-IAP_DECLARE,AP_FN_ATTR_SENTINEL 
	$ symscan.pl

Or write this line in ctags rc file ~/.ctags or /etc/ctags.conf: >

	-IAP_DECLARE,AP_FN_ATTR_SENTINEL 

On MS Windows you have to set variable HOME and put it into file ctags.cnf: >

	> (write file %userprofile%\ctags.cnf
	> set HOME=%userprofile%
	> symscan.pl

Read ctags manual for details on -I option.
------------------------------------------------------------------------------

vim:tw=78:ts=8:sw=8:ft=help:norl:
