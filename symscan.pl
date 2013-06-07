#!/usr/bin/perl

use strict;
use warnings;
use File::Find;
use Getopt::Long;

my $IS_MSWIN = $^O eq 'MSWin32';

# @ARGV=("$ENV{SBO_BASE}/Source/Infrastructure", "$ENV{SBO_BASE}/Source/Client");
if (@ARGV == 0) {
	print "Usage: symscan.pl {project_folders} [-o {outfile=1.repo.gz}]\n";
	exit;
}

my $outfile = '1.repo.gz';
GetOptions("o=s", \$outfile);
$outfile .= '.gz' if $outfile !~ /.gz/i;

my $sep = $IS_MSWIN? '\\': '/';
my @PRJ = @ARGV;
for (@PRJ) {
	s/$sep{2,}/$sep/g;
	s/$sep+$//;
	unless (-d $_) {
		print STDERR "*** cannot find folder $_\n";
		exit;
	}
}

my %files; # elem: fullname -> idx
my $symcnt = 0;

$| = 1;
print "=== scan files...\n";
open O, "| gzip > $outfile";
my $lastdir = '';
my $dir = ''; # $dir is for trans / to \ on MSWIN.
my ($idxdir, $idxfile) = (0,0);

my $lastSym;
my ($IDX_NAME, $IDX_FILEIDX, $IDX_LINE, $IDX_KIND, $IDX_EXTRA) = (0..10);
sub endWith # ($s, $pat)
{
	my ($len1, $len2) = (length($_[0]), length($_[1]));
	return $len1 > $len2 && rindex($_[0], $_[1]) == $len1 - $len2;
}

sub printSym # ($sym)
{
	my ($sym) = @_;
	unless (! defined($lastSym) || ($sym && $sym->[$IDX_LINE] eq $lastSym->[$IDX_LINE] && endWith($sym->[$IDX_NAME], $lastSym->[$IDX_NAME]))) {
#		print O "$name\t$fileidx\t$line\t$kind\t$extra\n";
		print O $lastSym->[$IDX_NAME], "\t", $lastSym->[$IDX_FILEIDX], "\t", $lastSym->[$IDX_LINE], "\t", $lastSym->[$IDX_KIND], "\t", $lastSym->[$IDX_EXTRA], "\n";
		++ $symcnt;
	}
	$lastSym = $sym;
}

# e.g.
# HELLO            macro         1 xx/hello.h       #define HELLO 100
# operator +       function     24 /home/builder/test/test2/xx/hello.h InnerC & operator + (int n);
# operator const RtecEventChannelAdmin::ConsumerQOS & prototype   187 /mnt/data/depot/BUSMB_B1/B1OD/20_DEV/c/9.01/sbo/Source/ThirdParty/LINUX/ACE/include/orbsvcs/Event_Utilities.h operator const RtecEventChannelAdmin::ConsumerQOS &(void);
my $re = qr/^(\S+)   # name 
			\s+(\S+) # type: function,macro,...
			\s+(\d+) # line
			\s+(\S+)  # file
			\s+(.*)$/xo;
my $re2 = qr/^(.*?)   # name 
			\s+(function|prototype|method|property|anchor|enum\s+constant|class) # type: function,macro,...
			\s+(\d+) # line
			\s+(\S+)  # file
			\s+(.*)$/xo;

sub getSym # ($file, $fileidx)
{
	my ($file, $fileidx) = @_;

#	open I, "ctags --c++-kinds=+px --languages=c,c++ --fields=+nS --excmd=pattern -u -R -f - " . join(' ', @PRJ) . " |";
	open I, "ctags -x --c++-kinds=+px -u --extra=+q \"$file\" |";

	while (<I>) {
		unless (/$re/ || /$re2/) {
			print "!!! unkonw line '$_'\n";
# 			die;
			next;
		}
		my ($name, $kind, $line, $file, $pat) = ($1, $2, $3, $4, $5);

		# set extra
		my $extra = '';
		my $idx;
		if ($kind eq 'function' || $kind eq 'method' || $kind eq 'prototype') {
			$idx = index($pat, '(');
			if ($idx > 0) {
				$extra = substr($pat, $idx);
			}
			else {
				$extra = $pat;
			}
		}
		else {
			$idx = index($pat, $name);
			if ($idx > 0) {
				$idx += length($name);
				$extra = substr($pat, $idx);
				if ($extra =~ /\w/o) {
					$extra =~ s/^\s+//;
				}
				else {
					$extra = '';
				}
			}
		}

		if ($extra) {
			if (length($extra) > 100) {
				$extra = substr($extra, 0, 100) . "...";
			}
			$extra =~ s/\t/ /g;
		}
		printSym([$name, $fileidx, $line, $kind, $extra]);
	}
	printSym(undef); # print lastone
	close I;
}

print O "!FOLDER ", join(' ', @PRJ), "\n";
print O "!LAST_UPDATE ", time(), "\n";

my $extRE = $ENV{SYM_SCAN_EXT} || 'c;cpp;h;hpp;cc;mak;cs;java;s';

if ($extRE) {
	local $_ = $extRE;
	print O "!EXTS $_\n";
	s/;|,/|/g;
	s/\s//g;
	s/[|]$//;
	$extRE = qr/\.($_)$/io;
}

sub mtime # ($file)
{
	my @a = stat($_[0]);
	return $a[9];
}

find(sub {
		if ($File::Find::dir ne $lastdir) {
			$lastdir = $File::Find::dir;
			++ $idxdir;
			$dir = $lastdir;
			$dir =~ s/\//\\/g if $IS_MSWIN;
			print O "\td$idxdir\t$dir\t", mtime($dir), "\n";
		}
		if (-f && !/\.(o|d)$/) {
			++$idxfile;
			print O "\tf$idxfile\t$_\td$idxdir\t", mtime($_), "\n";
			my $f = "$dir$sep$_";
			$files{$f} = "f$idxfile";

			if (!defined $extRE || /$extRE/) {
				getSym($f, "f$idxfile");
			}

			if ($idxfile % 100 == 0) {
				print "$idxfile files, $symcnt symbols...\r";
			}
		}
	},
	@PRJ
);
print "$idxfile files, $symcnt symbols are saved to repository $outfile.\n";

close O;
