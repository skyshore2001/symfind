VER=2.0
CXX=g++

#CXXFLAGS=-g -std=c++0x
CXXFLAGS=-O2 -std=c++0x

ifdef windir
  IS_MSWIN=1
else ifdef WINDIR
  IS_MSWIN=1
endif

ifdef IS_MSWIN
Bin=symfind.exe
CXXFLAGS+=-D_WINDOWS -U__STRICT_ANSI__

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
RelFiles=symscan.pl symfind.pl symsvr.pl __README__.txt symfind.vim $(RelWindows) $(RelLinux)

RelDir=symfind-$(VER)
RelPack=$(RelDir).tgz

all: $(Bin)

# method 1. make rel on Linux
# method 2. make on mingw, make on Linux, make rel on mingw or Linux
rel: all $(RelPack) 

$(RelPack): $(addprefix $(RelDir)/,$(RelFiles))
	tar zcf $(RelDir).tgz $(RelDir)

$(RelDir)/%: %
	@[ -d $(RelDir) ] || mkdir $(RelDir)
	cp $< $@

clean:
	-rm -rf $(Bin)

clobber:
	-rm -rf $(Bin) $(RelDir) $(RelPack)
