#CXXFLAGS=-g -std=c++0x
CXXFLAGS=-O2 -std=c++0x

ifdef windir
	CXXFLAGS+=-D_WINDOWS -U__STRICT_ANSI__
else
	CXXFLAGS+=-D_LINUX
endif

