#!/usr/bin/perl

use strict;
use warnings;
use Time::HiRes;

###### config {{{
my $MAX = 25;
my $EDITOR = 'vi';
#}}}

###### global {{{
my $IS_MSWIN = $^O eq 'MSWin32';
my $sep = $IS_MSWIN? '\\': '/';

my @REPOS; # elem: repo - {root, \@folders, \@files, \@symbols}
# file: [name, folder, [repo] ]
my ($IDX_NAME, $IDX_FOLDER, $IDX_REPO) = (0..10);
# symbol: [name, line, kind, extra, fileobj]
my ($IDX_LINE, $IDX_KIND, $IDX_EXTRA, $IDX_FILEOBJ) = (1..10);

my $g_forsvr = defined $ENV{SYM_SVR};

my $REPLACE_DIR = '';
my @REPLACE_DIR_PAT= ();

my $g_lastidx;
my $g_result; # {type=>[f|s], \@list}
#}}}

###### functions {{{
sub getFolder # ($fileobj)
{
	my ($fileobj) = @_;
	my ($d, $r) = ($fileobj->[$IDX_FOLDER], $fileobj->[$IDX_REPO]{root});
	if (@REPLACE_DIR_PAT >0) {
		for (@REPLACE_DIR_PAT) {
			$r =~ s/$_->[0]/$_->[1]/;
		}
	}
	if ($d eq '.') {
		$d = $r;
	}
	else {
		$d =~ s/^\.[\\\/]//;
		$d = $r . $sep . $d;
	}
	$d;
}

sub getFile # ($fileobj)
{
	my ($fileobj) = @_;
	my $d = getFolder($fileobj);
	return  $d . $sep . $fileobj->[$IDX_NAME];
}

sub queryFile # ($what, $out)
{
	my ($what, $out) = @_;
	my $cnt = 0;
	my @pat = split(/\s+/, $what);
#	print "=== query: '", join(' ', @pat), "'\n" unless $ENV{SYM_SVR};

	my @pat1;
	my @pat2;
	my $ic = 'i';
	for (@pat) {
		if (/[\/\\]$/) {
			chop;
			push @pat2, qr/$_/i;
		}
		else{
			if (s/!$//) {
				push @pat1, qr/$_/;
			}
			else {
				push @pat1, qr/$_/i;
			}
		}
	}
	$g_result = {type => 'f', list => []};
	$g_lastidx = -1;
	for (@REPOS) {
		my $repo = $_;
		for (@{$repo->{files}}) {
			my $name = $_->[$IDX_NAME];
			my $d;
			my $ok = 1;
			for (@pat1) {
				if ($name !~ /$_/) {
					$ok = 0;
					last;
				}
			}
			if ($ok) {
				$d = $_->[$IDX_FOLDER];
				for (@pat2) {
					if ($d !~ /$_/) {
						$ok = 0;
						last;
					}
				}
			}
			if ($ok) {
				++$cnt;
				$_->[$IDX_REPO] = $repo;
				$d = getFolder($_);
				print $out "$cnt:\t$name\t$d\n" or last;
				push @{$g_result->{list}}, $_;
				if ($cnt == $MAX) {
					print $out "... (max $MAX)\n";
					goto quit;
				}
			}
		}
	}
quit:
}

sub querySymbol # ($what, $out)
{
	my ($what, $out) = @_;
	my $cnt = 0;
	my @pat = split(/\s+/, $what);
#	print "=== query: '", join(' ', @pat), "'\n" unless $ENV{SYM_SVR};
	my @pat_main;
	my @pat_val;
	my $pat_kind;
	for (@pat) {
		if (/^#(.*)$/) {
			push @pat_val, qr/$1/i;
		}
		elsif (/^([a-z])$/) {
			$pat_kind = $1;
		}
		else{
			if (s/!$//) {
				push @pat_main, qr/$_/;
			}
			else {
				push @pat_main, qr/$_/i;
			}
		}
	}
	$g_result = {type => 's', list => []};
	$g_lastidx = -1;
	for (@REPOS) {
		my $repo = $_;
		for (@{$repo->{symbols}}) {
			next if $pat_kind && substr($_->[$IDX_KIND],0,1) ne $pat_kind;
			my $kind = $_->[$IDX_KIND];
			my $name = $_->[$IDX_NAME];
			my $ok = 1;
			for (@pat_main) {
				if ($name !~ /$_/) {
					$ok = 0;
					last;
				}
			}
			if ($ok && @pat_val) {
				#$ok = ($kind eq 'd' || $kind eq 'v' || $kind eq 'm' || $kind eq 'e');
				$ok = ($kind eq 'macro' || $kind eq 'variable');
				if ($ok) {
					my $ex = $_->[$IDX_EXTRA];
					for (@pat_val) {
						if (!defined $ex || $ex !~ /$_/) {
							$ok = 0;
							last;
						}
					}
				}
			}
			if ($ok) {
				my $fobj = $_->[$IDX_FILEOBJ];
				$fobj->[$IDX_REPO] = $repo;
				my $d = '';
				my $ex = $_->[$IDX_EXTRA] || '';
				my $f = $fobj->[$IDX_NAME];
				if ($g_forsvr) {
					$d = "\t" . getFolder($fobj);
				}
				my $ln = $_->[$IDX_LINE];
				push @{$g_result->{list}}, $_;
				++ $cnt;
				print $out "$cnt:\t$kind\t$name\t$ex\t$f:$ln$d\n" or last;
				if ($cnt == $MAX) {
					print $out "... (max $MAX)\n";
					goto quit;
				}
			}
		}
	}
quit:
}

sub gotoResult # ($idx)
{
	return unless defined($g_result) && defined($g_lastidx);
	my ($idx) = @_;
	if ($idx eq 'n') {
		$idx = $g_lastidx +1;
	}
	elsif ($idx eq 'N') {
		$idx = $g_lastidx -1;
	}
	return unless ($idx >= 0 && $idx < scalar(@{$g_result->{list}}));

	print "go ", $idx+1, "\n";
	$g_lastidx = $idx;
	my $rec = $g_result->{list}[$idx];
	if ($g_result->{type} eq 'f') {
		my $f = getFile($rec);
		system($EDITOR . " \"$f\"");
	}
	elsif ($g_result->{type} eq 's') {
		my $f = getFile($rec->[$IDX_FILEOBJ]);
		system($EDITOR  . " +$rec->[$IDX_LINE] \"$f\"");
	}
}
#}}}

###### main routine {{{

#@ARGV=qw/1.symbols/;
#@ARGV=qw'd:/bat/b1_tags.key';

$| = 1;
if (@ARGV < 1) {
	print "Usage: symfind.pl [repo-file(s)]\n";
	exit;
}

for (@ARGV) {
	-f or die "*** cannot open repo-file $_!\n";
}

#### load repo-files {{{
my ($fcnt, $scnt) = (0,0);
my $T0 = Time::HiRes::time();
for (@ARGV) {
	print "=== loading $_...\n";
	my $f = "gzip -dc $_ |";

	open IN, $f or die "cannot open file '$f'\n";
	my $ismeta = 0;
	my $repo;
	my ($curdir, $curfobj);
	while (<IN>) {
		if (/^!/o) {
			if (/^!ROOT\s+(.+)/) {
				if (!$ismeta) {
					$repo = {
						root => $1,
						folders => [],
						files => [],
						symbols => []
					};
					push @REPOS, $repo;
				}
				$ismeta = 1;
			}
			next;
		}
		$ismeta = 0;
		chomp;
		my @a = split("\t");
		if ($a[0] eq '') {
			my $t = substr($a[1], 0, 1);
			if ($t eq 'd') {
				$curdir = $a[2];
				push @{$repo->{folders}}, $curdir; # name
			}
			elsif ($t eq 'f') {
				$curfobj = [$a[2], $curdir]; # name, folder
				push @{$repo->{files}}, $curfobj;
				++ $fcnt;
			}
		}
		else {
			if ($a[$IDX_EXTRA] && length($a[$IDX_EXTRA]) > 300) {
				print $a[$IDX_NAME], "=>",length($a[$IDX_EXTRA]), "\n";
			}
			$a[$IDX_FILEOBJ] = $curfobj;
			push @{$repo->{symbols}}, \@a;
			++ $scnt;
		}
	}
	close IN;
}

printf "load $fcnt files, $scnt symbols in %.3fs.\n", Time::HiRes::time()-$T0;
#}}}

#### CUI {{{
	print "(for symsvr)\n" if $g_forsvr;
	print "> ";
	print "\n" if $g_forsvr;
	while (<STDIN>) {
		chomp;
		goto nx if $_ eq '';
		my ($cmd, $arg) = split(/\s+/, $_, 2);
		$arg = '' unless defined $arg;
		if ($cmd eq 'f') {
			queryFile($arg, \*STDOUT);
		}
		elsif ($cmd eq 's') {
			querySymbol($arg, \*STDOUT);
		}
		elsif ($cmd eq 'q') {
			print "=== quit.\n";
			last;
		}
		elsif ($cmd eq 'max') {
			if ($arg) {
				my $val = $arg +0;
				if ($val < 10) {
					$val = 10;
				}
				$MAX= $arg;
			}
			print "MAX=$MAX\n";
		}
		elsif (!$g_forsvr && ($cmd eq 'go' || $cmd eq 'n' || $cmd eq 'N') ) {
			my $idx;
			if ($cmd eq 'go') {
				$idx = (defined $arg)? $arg - 1: 1;
			}
			else {
				$idx = $cmd;
			}
			gotoResult($idx);
		}
		elsif ($cmd eq 'editor') {
			if ($arg) {
				$EDITOR = $arg;
			}
			print "EDITOR $EDITOR\n";
		}
		elsif ($cmd eq 'dir') {
			if ($arg) {
				$REPLACE_DIR = $arg;
				@REPLACE_DIR_PAT = ();
				for my $eq (split(/;/, $REPLACE_DIR)) {
					local @_ = split(/=/, $eq, 2);
					push @REPLACE_DIR_PAT, \@_;
				}
			}
			print "dir $REPLACE_DIR\n";
		}
		elsif ($cmd eq '?') {
			print <<END;
f {patterns}
  file search
s {patterns}
  symbol search
go [num=1]
  open the {num}th result 
n/N
  go next or previous
max [num=25]
  set max displayed result
editor [prog=vi]
  set default viewer for go.
replace [old=new]
  replace the real path from "old" to "new"
?
  show this help.
q
  quit

-------- hint for pattern:
end with / - find file in dir
begin with # - search symbol that value matches the pattern
f|t|...  - find symbol of kind=f or t ...

END
		}
		else {
			print "!!! unknown cmd: $cmd\n";
		}
nx:
		print "> ";
		print "\n" if $g_forsvr;
	}
#}}}
#}}}

# vim: set foldmethod=marker :
