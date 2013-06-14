#!/usr/bin/perl

use strict;
use warnings;
use File::Find;
use Getopt::Long;
use IPC::Open2;
use Time::HiRes qw/time/;

my $IS_MSWIN = $^O eq 'MSWin32';

###### config {{{
my $extRE = $ENV{SYM_SCAN_EXT} || 'c;cpp;h;hpp;cc;mak;cs;java;s';
my $xextRE = $ENV{SYM_SCAN_EX_EXT} || 'o;obj;d';

#}}}

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
my $T0 = time();
print "=== scan files...\n";
open O, "| gzip > $outfile";
my $lastdir = '';
my $dir = ''; # $dir is for trans / to \ on MSWIN.
my ($idxdir, $idxfile) = (0,0);

my ($IDX_NAME, $IDX_FILEIDX, $IDX_LINE, $IDX_KIND, $IDX_EXTRA) = (0..10);

# e.g.
# HELLO            macro         1 xx/hello.h       #define HELLO 100
# operator +       function     24 /home/builder/test/test2/xx/hello.h InnerC & operator + (int n);
# operator const RtecEventChannelAdmin::ConsumerQOS & prototype   187 /mnt/data/depot/BUSMB_B1/B1OD/20_DEV/c/9.01/sbo/Source/ThirdParty/LINUX/ACE/include/orbsvcs/Event_Utilities.h operator const RtecEventChannelAdmin::ConsumerQOS &(void);
my $re = qr/^([^\t]+)   # name 
			\t([^\t]+) # type: function,macro,...
			\t(\d+) # line
			\t([^\t]+) # file
			\t(.*?)\s*$/xo;

my $ctag_out;
sub getSym # ($file, $fileidx)
{
	my ($file, $fileidx) = @_;

	if (!defined $ctag_out) {
		open2(\*I, $ctag_out, "ctags -x --c++-kinds=+px -u --filter=yes --filter-terminator=") or die "fail to open dctags!\n";
	}
	if (!defined $file) {
		print $ctag_out ".\n";
		close $ctag_out;
		close I;
		undef $ctag_out;
		return;
	}
	print $ctag_out "$file\n";

	while (<I>) {
		last unless /\S/;
		unless (/$re/) {
			print "!!! unknown line '$_'\n";
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
		print O "$name\t$fileidx\t$line\t$kind\t$extra\n"; 
		++ $symcnt;
	}
}

print O "!FOLDER ", join(' ', @PRJ), "\n";
print O "!LAST_UPDATE ", time(), "\n";

if ($extRE) {
	local $_ = $extRE;
	print O "!EXTS $_\n";
	s/;|,/|/g;
	s/\s//g;
	s/[|]$//;
	$extRE = qr/\.($_)$/io;
}
if ($xextRE) {
	local $_ = $xextRE;
	print O "!XEXTS $_\n";
	s/;|,/|/g;
	s/\s//g;
	s/[|]$//;
	$xextRE = qr/\.($_)$/io;
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
		if (-f && (!defined $extRE || !/$xextRE/)) {
			++$idxfile;
			print O "\tf$idxfile\t$_\td$idxdir\t", mtime($_), "\n";
			my $f = "$dir$sep$_";
			$files{$f} = "f$idxfile";

			if (!defined $extRE || /$extRE/) {
				getSym($f, "f$idxfile");
			}

			if ($idxfile % 100 == 0) {
				print "$idxfile files, $symcnt symbols ...\r";
			}
		}
	},
	@PRJ
);
getSym(undef, undef); # close the sub-process
print "$idxfile files, $symcnt symbols are saved to repository $outfile.\n";
printf "(%.2lf seconds cost.)\n", time()-$T0;

close O;
