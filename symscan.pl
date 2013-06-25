#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Find;
use File::Basename;
use Getopt::Long;
use IPC::Open2;
use Time::HiRes;

###### config {{{
my $REPO_VER = 2;
my $repofile = '1.repo.gz';
my $TAGSCAN_PAT = '*.c;*.cpp;*.h;*.hpp;*.cc;*.mak;*.cs;*.java;*.s';
my $IGNORE_PAT = '*.o;*.obj;*.d;.*';
#}}}

###### globals {{{
my $IS_MSWIN = $^O eq 'MSWin32';
my $sep = $IS_MSWIN? '\\': '/';

my $CWD = mygetcwd();
my $PROG = getAbsPath($0);

my $outfile;

my $symcnt = 0;
my $filecnt = 0;
my $updFilecnt = 0;

my ($tagScanRE, $ignoreRE);

#}}}

###### toolkit {{{
sub mtime # ($file)
{
	my @a = stat($_[0]);
	return $a[9];
}

# e.g. "*.c;tags;.*" -> /\.c$|^tags$|^\./i OR /^(.*?\.c|tags|\..*?)$/i
sub patToRE # ($pat)
{
	local $_ = shift;
	s/\s//g;
	# escape
	s/([.|()^\$])/\\$1/g;
	# remove empty
	s/;+/|/g;
	s/;$//;
	# replace '*'
	s/\*/.*?/g;

	return qr/^($_)$/i;
}
#}}}

###### function {{{
sub mygetcwd
{
	local $_ = getcwd();
	s/\//\\/g if $IS_MSWIN;
	$_;
}

# require: $CWD, $IS_MSWIN, $sep
sub getAbsPath # ($path)
{
	local $_ = shift;
	if ($_ eq '.') {
		return $CWD;
	}
	s/^\.[\/\\]//;  # ./symscan.pl -> symscan.pl
	unless (/^[\/\\]/ || ($IS_MSWIN && /^\w:/))
	{
		$_ = $CWD . $sep . $_;
	}
	$_;
}

my $ctag_out;
sub getSym # ($file)
{
	my ($file) = @_;
	my $cnt = 0;

	if (!defined $ctag_out) {
		return if !defined $file;
		my $CTAGS = dirname($PROG) . $sep . 'stags';
		$CTAGS .= '.exe' if $IS_MSWIN;
		die "*** $CTAGS does not exist or cannot run!" unless -f $CTAGS;
		print "=== use ctags: $CTAGS\n" if $ENV{DEBUG};
		# --format=99: my own format
		# -u: don't sorting
		open2(\*I, $ctag_out, "\"$CTAGS\" -x --format=99 --c++-kinds=+px -u --filter=yes --filter-terminator=") or die "fail to open stags!\n";
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
		chop; # remvoe "\n"
		chop if /\s$/o; # remove "\r"
		last unless /\S/o;
		print O $_, "\n";
		++ $cnt;
	}
	return $cnt;
}

# require: $REPO
sub loadRepo # ($f)
{
	my ($f) = @_;
	$f = "gzip -dc $f |";
	open IN, $f or die "cannot open file $f\n";
	my @repos = ();
	my $repo;
	my ($curdir, $curfileobj);
	my $ismeta = 0;
	while (<IN>) {
		if (/^!(\w+)\s+(.*)/o) {
			if (! $ismeta) {
				$repo = {
					meta => {},
					files => {},
				};
				undef $curdir;
				undef $curfileobj;
				push @repos, $repo;
				$ismeta = 1;
			}
			$repo->{meta}{$1} = $2;
		}
		elsif (/^\t(d|f)\t([^\t]+)\t(\d+)/o) {
			$ismeta = 0;
			my ($type, $name, $mtime) = ($1, $2, $3);
			if ($type eq 'f') {
				my $fileobj = {mtime => $mtime, content => $_};
				!$curdir && die "*** bad repo!";
				$name = $curdir . $sep . $name;
				$repo->{files}{$name} = $fileobj;

				$curfileobj = $fileobj;
			}
			else {
				$curdir = $name;
			}
		}
		else {
			$curfileobj->{content} .= $_;
		}
	}
	close IN;
	@repos;
}

# require: O
sub handleDir # ($name, $dirname)
{
	my ($name, $dirname) = @_;
	$dirname =~ s/\//\\/g if $IS_MSWIN;
	my $fname = $name eq '.'? $dirname: $dirname . $sep . $name;
	my $mtime1 = mtime($name);
	print O "\td\t$fname\t$mtime1\n";
}

# require: O, $filecnt, $symcnt
sub handleFile # ($name, $dirname, $repo)
{
	my ($name, $dirname, $repo) = @_;
	$dirname =~ s/\//\\/g if $IS_MSWIN;
	my $forUpdate = defined $repo;
	my $fname = $dirname . $sep . $name;
	my $mtime1 = mtime($name);

	my $fileobj;
	if ($repo && exists $repo->{files}{$fname}) {
		$fileobj = $repo->{files}{$fname};
	}

	++ $filecnt;
	if (!(defined $fileobj) || $mtime1 > $fileobj->{mtime}) {
		print O "\tf\t$name\t$mtime1\n";
		++ $updFilecnt if $forUpdate;
		print "### scan $fname\n" if $ENV{DEBUG};

		if (!defined $tagScanRE || $name =~ /$tagScanRE/) {
			my $f = mygetcwd() . $sep . $name;
			$symcnt += getSym($f);
		}
	}
	else { # update
		print O $fileobj->{content};
	}
	if ($filecnt % 100 == 0) {
		if (! $forUpdate) {
			print "$filecnt files, $symcnt symbols ...\r";
		}
		else {
			print "$filecnt files ($updFilecnt updates with $symcnt symbols) ...\r";
		}
	}
}

#}}}

###### main routine {{{
$| = 1;
# @ARGV=("$ENV{SBO_BASE}/Source/Infrastructure", "$ENV{SBO_BASE}/Source/Client");
if (@ARGV == 0) {
	print "Usage: symscan.pl {folder(s)|repo-file(s)} [-o {outfile=1.repo.gz}]\n";
	exit;
}

GetOptions("o=s", \$outfile);

for (@ARGV) {
	s/$sep{2,}/$sep/g;
	s/$sep+$//;
	$_ = getAbsPath($_);
	unless (-d $_ || -f $_) {
		print STDERR "*** cannot find repo-file or folder $_\n";
		exit;
	}
}
if ($ARGV[0] =~ /\.gz$/) {
	$repofile = $ARGV[0];
}
if (defined $outfile) {
	$outfile .= '.gz' if $outfile !~ /.gz/i;
}
else {
	$outfile = $repofile;
}

### process each repo-file update or folder scan

my $fdopened;
my %scanedRoot;  # avoid the same root to be scaned repeatly 
for (@ARGV) {
	my $forUpdate;

	### repo-file in memory (for update)
	my @repos; # elem: {\%meta, \%files}
	# meta: $key => $value
	# files: $filename => {name, mtime, content}

	if (-d) {
		@repos = ({
			meta => {
				ROOT => $_,
			}
		});
	}
	elsif (-f) {
		print "=== load repo-file $_...\n";
		@repos = loadRepo($_);
		$forUpdate = 1;
	}
	# NOTE: !!! ENSURE O is opened after loading first repo (as outfile may be the same as the first repo)
	if (!$fdopened)
	{
		open O, "| gzip > $outfile";
		binmode O; # avoid "\r" on mswindows
		$fdopened = 1;
	}

	for (@repos) {
		my $repo = $_;
		my $root = $repo->{meta}{ROOT};
		next if exists $scanedRoot{$root};
		$scanedRoot{$root} = 1;

		print O "!ROOT $root\n";
		print O "!REPO_VER ", ($_->{meta}{REPO_VER} || $REPO_VER), "\n";
		print O "!LAST_UPDATE ", time(), "\n";
		print O "!TAGSCAN_PAT ", $TAGSCAN_PAT, "\n";
		print O "!IGNORE_PAT ", $IGNORE_PAT, "\n";

		$ignoreRE = patToRE($IGNORE_PAT);
		$tagScanRE = patToRE($TAGSCAN_PAT);

		my $T0 = Time::HiRes::time();
		chdir $root;
		($filecnt, $updFilecnt, $symcnt) = (0,0,0);
		print "=== scan folder $root...\n";

		# NOTE: ENSURE files are processed before sub-dirs
		find({
			preprocess => sub {
				my @r;
				for (@_) {
					next if $_ eq '.' or $_ eq '..';
					if (!defined $ignoreRE || !/$ignoreRE/) {
						if (-f)
						{
							handleFile($_, $File::Find::name, $forUpdate? $repo: undef);
						}
						else {
							push @r, $_;
						}
					}
				}
				@r;
			},

			wanted => sub {
				handleDir($_, $File::Find::dir);
			},
		}, '.');

		my $t = Time::HiRes::time()-$T0;
		if (! $forUpdate) {
			printf "$filecnt files, $symcnt symbols are saved to repository $outfile in %.3lfs.\n", $t;
		}
		else {
			printf "$filecnt files ($updFilecnt updates with $symcnt symbols) in repository $outfile in %.3lfs.\n", $t;
		}
	}
}
chdir $CWD;
getSym(undef); # close the sub-process
close O;

#}}}

# vim: set foldmethod=marker :
