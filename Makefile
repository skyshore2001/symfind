VER=2.3
CXX=g++

ifndef BUILD_DEBUG
CXXFLAGS=-O2 -std=c++11
else
CXXFLAGS=-g -std=c++11
endif

ifdef windir
  IS_MSWIN=1
else ifdef WINDIR
  IS_MSWIN=1
endif

ifdef IS_MSWIN
Bin=symfind.exe
CXXFLAGS+=-D_WINDOWS -U__STRICT_ANSI__
LDFLAGS+=-static

symfind.exe: symfind.cpp
	$(CXX) $(CXXFLAGS) $< $(LDFLAGS) -o $@ 

else
Bin=symfind
CXXFLAGS+=-D_LINUX

symfind: symfind.cpp
	$(CXX) $(CXXFLAGS) $< $(LDFLAGS) -o $@ 

endif

RelWindows=symfind.exe stags.exe gzip.exe install_windows.bat
RelLinux=symfind stags install_linux.sh

ifdef IS_MSWIN
RelFiles=symscan.pl symfind.pl symsvr.pl __README__.txt symfind.vim $(RelWindows) 
RelDir=symfind-$(VER)-w32
else
RelFiles=symscan.pl symfind.pl symsvr.pl __README__.txt symfind.vim $(RelLinux)
# TODO: now only for centos 7 (el7). try `uname -r`
RelDir=symfind-$(VER)-el7
endif

RelPack=$(RelDir).tgz

all: $(Bin)

# method 1. make rel on Linux
# method 2. make on mingw, make on Linux, make rel on mingw or Linux
dist: all $(RelPack) 
	@echo === package $(RelPack) is created.

$(RelPack): $(addprefix $(RelDir)/,$(RelFiles))
	tar zcf $(RelDir).tgz $(RelDir)

$(RelDir)/%: %
	@[ -d $(RelDir) ] || mkdir $(RelDir)
	cp $< $@

clean:
	-rm -rf $(Bin)

clobber:
	-rm -rf $(Bin) $(RelDir) $(RelPack)

install:
	@sh install_linux.sh

uninstall:
	@sh install_linux.sh -u

