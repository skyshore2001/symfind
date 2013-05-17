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

$| = 1;
print "=== scan files...\n";
open O, "| gzip > $outfile";
my $lastdir = '';
my $dir = ''; # $dir is for trans / to \ on MSWIN.
my ($idxdir, $idxfile) = (0,0);
find(sub {
		if ($File::Find::dir ne $lastdir) {
			$lastdir = $File::Find::dir;
			++ $idxdir;
			$dir = $lastdir;
			$dir =~ s/\//\\/g if $IS_MSWIN;
			print O "\td$idxdir\t$dir\n";
		}
		if (-f && !/\.(o|d)$/) {
			++$idxfile;
			print O "\tf$idxfile\t$_\td$idxdir\n";
			$files{"$dir$sep$_"} = "f$idxfile";

			if ($idxfile % 1000 == 0) {
				print "$idxfile files...\r";
			}
		}
	},
	@PRJ
);
print "$idxfile files saved.\n";

print "=== scan symbols\n";
open I, "ctags --c++-kinds=+px --languages=c,c++ --fields=+nS --excmd=pattern -u -R -f - " . join(' ', @PRJ) . " |";

my ($IDX_NAME, $IDX_PATH, $IDX_PAT, $IDX_KIND, $IDX_LINE, $IDX_LAST) = (0..10);
# f,p:signature/class; v,d:PAT
my $symcnt = 0;
while (<I>) {
	unless (/^([^\t]+)
			\t([^\t]+)
			\t\/\^(.*?)\s*\$?\/;"
			\t(\w)\t
			line:(\d+)
			(?:\tclass:(\w+))?
			(?:\tsignature:(.+))?
			/x) {
		print "!!! unkonw line $_\n";
		die;
		next;
	}
	my ($name, $file, $pat, $kind, $line, $cls, $sig) = ($1, $2, $3, $4, $5, $6, $7);
	my $extra = '';
	if ($kind eq 'f' || $kind eq 'p') {
		if ($cls) {
			$name = $cls . '::' . $name;
		}
		if ($sig) {
			$extra = $sig;
		}
	}
	elsif ($kind eq 'd') {
		if ($pat =~ /define\s+\S+\s+(\w+)/) {
			$extra = $1;
		}
	}
	elsif ($kind eq 'v') {
		if ($pat =~ /=\s*(.+?)\s*;/) {
			$extra = $1;
		}
	}
	if ($extra) {
		$extra =~ s/\t/ /g;
	}
	$file = $files{$file};
	print O "$name\t$file\t$line\t$kind\t$extra\n";

	++ $symcnt;
	if ($symcnt % 1000 == 0) {
		print "$symcnt symbols...\r";
	}
}
print "$symcnt symbols saved to repository $outfile.\n";

close O;
close I;
