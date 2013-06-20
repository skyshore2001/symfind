*symfind.txt*	For Vim version 7.3.  Last change: 2013 June 20

	    Symfind - Locate finds and symbols for large project
		    Liang, Jian - 2013/5

|1| Introduction					|sf-intro|
|2| Install						|sf-install|
|3| Quick Start						|:Symfind|
|4| Using Symfind					|sf-using|
	|4.1| Repository				|sf-repo|
	|4.2| Query syntax				|sf-query|
	|4.3| Options					|sf-options|
|5| Contact me						|sf-contact|

==============================================================================
*1* Introduction						*sf-intro*

Symfind can be used to scan and locate file or symbol in your project folder. 
It can work with vim.

Why do we use this tool? Let's compare to some similar tools:
	ctags
	vim + fuzzyfind
	cscope
	source navigator
	global

Key features of Symfind:
- natural search pattern for file or symbol (|sf-query|)
  e.g. Search a symbol that contains "res" and "linux". Most tools cannot do
  this partly search and require full symbol name or at least the part it
  begins with. Some tools can use regexp pattern like ".*res.*linux.*", but
  you have to try ".*linux.*res.*" if the order is different. And more, it's
  very slow. 
 
  Symfind directly use the natural pattern "res linux". And it performs in-memory
  search, so very fast.

- small database
  The size of my project folder is ~7G, and contains ~60000 source files. ctags 
  generates tag file that is >300M. 
  Source navigator produce >1G repository.
  Symfind scans the folder in 3 minutes, and the repo-file is about 17M.

- simple, stable and reliable
  In my project, I tried some tools, some cannot find some symbol, or cannot find xref.
  I use cscope in vim, but it often lose connection.
  Symfind uses grep directly on orignial files, slower but safe.

- value search for macro or variable
  Other tools have to use grep. 

- vim integration

Symfind is designed for easy locating symbols in large project. It is powerful 
for symbol lookup, and use simple strategy for reference lookup. It's simple,
stable, reliable and fast.

==============================================================================
*2* Install							*sf-install*

On MS Windows, you need install Perl.
Modify install_windows.bat for your path and just run it. It's easy and 
just copy files to your folder.

On Linux, modify path in script install_linux and run it. 

stags (for Linux) and stags.exe (for Windows) is attached. It's used by
symscan.pl. stags is a branch of ctags with slight change that works better
with Symfind. You can find source code here: <TODO>

==============================================================================
*3*  Quick Start 						*:Symfind*

First, scan your project using symscan.pl. >
	$ symscan.pl $SBO_BASE/Source -o b1

It will create repository b1.gz. If you don't use option "-o", the default
repository is named 1.repo.gz.

To update the repository: >
	$ symscan.pl b1.gz

After the repo is ready, you can run symfind.pl or symsvr.pl.  >
	$ symfind.pl b1.gz

It's the command-line interface: >
	> ?
	(show command help)
	> f string cpp
	(find file name that has "string" and "cpp", case-insensitive)
	> s sbo string
	(find symbol name that has "sbo" and "string", case-insensitive)
	> go 2
	(go to the 2nd location in the result list, by default open file using vi)
	> n
	(go to the next location)
	> N
	(go to the previous location)
	> q
	(quit)
	
To work with vim, first run symsvr: >
	$ symsvr.pl b1.gz

Then open symfind window in vim/gvim: >
	:Symfind
OR >
	\sf

Now input command in the Symfind window, and go to the result by press <Enter>
or double-click.

==============================================================================
*4*  Using Symfind							*sf-using*

*4.1* Symfind Repository file (repo-file) 				*sf-repo*

A repo-file (e.g. 1.repo.gz) is a text file compressed using gzip. It contains
one or more repository. Each repository is for one folder. e.g. >
	$ symscan.pl /home/data/dir1 /home/data/dir2
The generated repo-file actually contains 2 repos respectively for the 2
folders.

To update the repo-file actually re-scan the original 2 folders: >
	$ symscan.pl 1.repo.gz

To update and add new folder to the repository: >
	$ symscan.pl 1.repo.gz /home/data/dir3

*4.2* Query syntax						*sf-query*
Query by words seperated by space: >
	> s foo bar
	(symbols contain "foo" and "bar", case-insensitive)

Regular expression is suppported: >
	> f ^sbo .cpp$
	(files start with "sbo" and end with "cpp")

Search in folder: xxx/ ~
For files, pattern that ends with "/" means search folder name: >
	> f ace thirdparty/
	(files that contain "ace" and in a folder that contains "thirdparty")

Search symbol kind~
For symbols, the result lists symbol names and kinds. To filter the result by
kind, use the first character of the kind name, e.g. "c" for "class": >
	> s string
	(list symbols match "string", there are kinds of "prototype", "class",
	or "function")
	> s string c
	(just find "class")

Search symbol value: #xxx ~
For symbols, pattern that starts with "#" means search in values. E.g. you get
a error code -5002 and want to see if some macro is defined by this value: >
	> s #-5002

You can composite all the features. e.g. >
	> s ^dbm #-5002 m
	(start with "dbm", value contains "-5002" and is a "macro")

*4.3* Options 							*sf-options*

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
	> dir /mnt/data/depot/sbo=/mnt/data/depot2/sbo

OR simply >
	> dir depot=depot2

The result folder name will be checked and replaced if neccessary.

==============================================================================
*5* Contact me						*sf-contact*

Liang, Jian - skyshore@gmail.com

Thanks to the following softwares that give my ideas: >

	ctags 
	vgdb
	Visual AssistX

vim:tw=78:ts=8:sw=8:ft=help:norl: