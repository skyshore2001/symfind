#!/usr/bin/perl

use strict;
use warnings;

my %folders; # elem: $idx => $folder
my %files; # elem: $idx => {name, dir}

#@ARGV=qw/1.symbols/;
#@ARGV=qw'd:/bat/b1_tags.key';

if (@ARGV < 1) {
	print "Usage: symfind [repo]\n";
	exit;
}
my $MAX = 25;
my $EDITOR = 'vi';
my $outputln = defined $ENV{SYM_SVR};

my $REPLACE_DIR = '';
my @REPLACE_DIR_PAT= ();

my @symbols; # elem: [$NAME, $FILE, $LINE, $KIND $EXTRA]
my ($IDX_NAME, $IDX_FILE, $IDX_LINE, $IDX_KIND, $IDX_EXTRA) = (0..10);

my $g_result; # {type=>[f|s], list}

my $f = $ARGV[0];
if ($f =~ /\.gz$/) {
	#$f = "zcat $f |";
	$f = "gzip -dc $f |";
}
open IN, $f or die "cannot open file $f\n";
while (<IN>) {
	next if /^!/o;
	chomp;
	my @a = split("\t");
	if ($a[0] eq '') {
		my $t = substr($a[1], 0, 1);
		if ($t eq 'd') {
			$folders{$a[1]} = $a[2];
		}
		elsif ($t eq 'f') {
			$files{$a[1]} = {name => $a[2], dir => $a[3]};
		}
	}
	else {
		if ($a[$IDX_EXTRA] && length($a[$IDX_EXTRA]) > 300) {
			print $a[$IDX_NAME], "=>",length($a[$IDX_EXTRA]), "\n";
		}
		push @symbols, \@a;
	}
}
close IN;

my @filelist = values(%files);
print "load " . scalar(@filelist) . " files.\n";
print "load " . scalar(@symbols) . " symbols.\n";

sub getFolderByIdx # ($idx)
{
	my ($idx) = @_;
	my $d = $folders{$idx};
	if (@REPLACE_DIR_PAT >0) {
		for (@REPLACE_DIR_PAT) {
			$d =~ s/$_->[0]/$_->[1]/;
		}
	}
	return $d;
}

sub getFile # ($fileobj)
{
	my ($fileobj) = @_;
	return  getFolderByIdx($fileobj->{dir}) . '/' . $fileobj->{name};
}

sub getFileByIdx # ($fileidx)
{
	return getFile($files{$_[0]});
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
	for (@filelist) {
		my $k = $_->{name};
		my $ex;
		my $ok = 1;
		for (@pat1) {
			if ($k !~ /$_/) {
				$ok = 0;
				last;
			}
		}
		if ($ok) {
			$ex = $folders{$_->{dir}};
			for (@pat2) {
				if ($ex !~ /$_/) {
					$ok = 0;
					last;
				}
			}
		}
		if ($ok) {
			++$cnt;
			$ex = getFolderByIdx($_->{dir});
			print $out "$cnt:\t$k\t$ex\n" or last;
			push @{$g_result->{list}}, $_;
			if ($cnt == $MAX) {
				print $out "... (max $MAX)\n";
				last;
			}
		}
	}
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
	for (@symbols) {
		next if $pat_kind && substr($_->[$IDX_KIND],0,1) ne $pat_kind;
		my $kind = $_->[$IDX_KIND];
		my $key = $_->[$IDX_NAME];
		my $ok = 1;
		for (@pat_main) {
			if ($key !~ /$_/) {
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
			my $f = $files{$_->[$IDX_FILE]}{name};
			my $d = '';
			my $ex = $_->[$IDX_EXTRA] || '';
			if ($ENV{SYM_SVR}) {
				$d = "\t" . getFolderByIdx($files{$_->[$IDX_FILE]}{dir}, 1);
			}
			my $ln = $_->[$IDX_LINE];
			push @{$g_result->{list}}, $_;
			++ $cnt;
			print $out "$cnt:\t$kind\t$key\t$ex\t$f:$ln$d\n" or last;
			if ($cnt == $MAX) {
				print $out "... (max $MAX)\n";
				last;
			}
		}
	}
}

=pod
use IO::Socket::INET;

	my $sock = IO::Socket::INET->new (
		#LocalAddr => '127.0.0.1',
		LocalPort => 9999,
		Reuse => 1,
# 			ReuseAddr => 1,
# 			ReusePort => 1,
		Proto => 'tcp',
		Listen => 1,
	) or die "cannot open socket: $!";

	print "listen on 9999\n";
	while (my $ses = $sock->accept()) {
		querySymbol($ses);
		$ses->close();
	}
=cut

	$| = 1;
	print "(for symsvr)\n" if $outputln;
	print "> ";
	print "\n" if $outputln;
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
		elsif ($cmd eq 'go' && !$ENV{SYM_SVR}) {
			my $idx = $arg-1;
			if ($g_result && $idx >= 0 && $idx < scalar($g_result->{list})) {
				my $rec = $g_result->{list}[$idx];
				if ($g_result->{type} eq 'f') {
					my $f = getFile($rec);
					system($EDITOR . " \"$f\"");
				}
				elsif ($g_result->{type} eq 's') {
					my $f = getFileByIdx($rec->[$IDX_FILE]);
					system($EDITOR  . " +$rec->[$IDX_LINE] \"$f\"");
				}
			}
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
go {num}
  open the {num}th result 
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
end with ! - dont ignore case
end with / - find file in dir
f|t|...  - find symbol of kind=f or t ...

END
		}
		else {
			print "!!! unknown cmd: $cmd\n";
		}
nx:
		print "> ";
		print "\n" if $outputln;
	}
