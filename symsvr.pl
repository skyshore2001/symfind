#!/usr/bin/perl

use strict;
use warnings;
use IO::Handle;

###### config
my $DEF_PORT = 20000;
my $INST_NO = 0;
my $DEBUG = $ENV{DEBUG};
my $IS_MSWIN = $^O eq 'MSWin32';
my $SYMFIND = $ENV{SYMFIND} || 'symfind';

###### global
my $g_tgtpid;
my $g_isclient = 0;

open NEWERR, ">&STDERR";
select NEWERR;
$| = 1;

###### toolkit {{{
sub mychop
{
	$_[0] =~ s/[ \r\n]+$//;
}

sub msg # ($msg, [$force=0])
{
	print NEWERR $_[0] if $DEBUG || $_[1];
}

sub mydie # ($msg)
{
	msg("*** error: $_[0]\n", 1);
	kill 9, $g_tgtpid if $g_tgtpid;
	exit(-1);
}

sub getTcpPort # ()
{
	my $p = $ENV{TCP_PORT} || $DEF_PORT + $INST_NO;
	msg("=== TCP_PORT=$p\n", 1) if !$g_isclient;
	return $p;
}

package CommInet; # {{{
our $TCP_PORT;

use IO::Socket::INET;
sub new # ({isclient=>0})
{
	my $clsName = shift;
	my %opt = @_;
	my $this = bless {
		type => 'inet',
		isclient => $opt{isclient}
	}, $clsName;
	$TCP_PORT = main::getTcpPort();
	if ($this->{isclient}) {
		$this->{sock} = IO::Socket::INET->new (
			PeerAddr => '127.0.0.1',
			PeerPort => $TCP_PORT,
			Proto => 'tcp',
		) or main::mydie("cannot open socket.");
	}
	else {
		$this->{sock} = IO::Socket::INET->new (
			#LocalAddr => '127.0.0.1',
			LocalPort => $TCP_PORT,
			Reuse => !$IS_MSWIN,
# 			ReuseAddr => 1,
# 			ReusePort => 1,
			Proto => 'tcp',
			Listen => 1,
		) or main::mydie("cannot open socket.");
	}
	$this->{sock}->autoflush(1);
	$this;
}

sub destroy
{
	my $this = shift;
	if ($this->{session}) {
		$this->{session}->close();
	}
	$this->{sock}->close();
}

sub put # ($line)
{
	my $this = shift;
	my $line = $_[0];
	my $sck = $this->{isclient}? $this->{sock}: $this->{session} ;
	print $sck $line;
}

sub get
{
	my $this = shift;
	my $sck;
	local $_;
	if ($this->{isclient}) {
		$sck = $this->{sock};
	}
	else {
		if ($this->{session}) {
			$this->{session}->close();
			delete $this->{session};
		}
		$sck = $this->{session} = $this->{sock}->accept();
	}
	$_ = <$sck>;
}

# sub accept
# {
# 	my $this = shift;
# 	if ($this->{session}) {
# 		$this->{session}->close();
# 		delete $this->{session};
# 	}
# 	$this->{session} = $this->{sock}->accept();
# 	$this->{session}->autoflush(1);
# 	1;
# }
#}}}
package main;
#}}}

###### function {{{
sub runClient # ($cmds)
{
	my ($cmds) = @_;
	my $comm = CommInet->new(isclient=> 1) or die "*** cannot start client!";
	$comm->put("$cmds\n");

	my $line;
	while(defined ($line = $comm->get()))
	{
		print $line;
	}
	$comm->destroy();
}

sub parseRetLine  # ($comm, $line, $hideout)
{
	my ($comm, $line, $hideout) = @_;
	$comm->put("$line\n") if $comm && !$hideout;
}

sub execCmd # ($comm, $cmd, [$hideout=0])
{
	my ($comm, $cmd, $hideout) = @_;
	if (defined $cmd)
	{
		print MAIN_WR "$cmd\n";
		msg("(cmd) '$cmd'\n");
	}
	while(<MAIN_RD>)
	{
		mychop($_);
		if(/^>/) {
			return 1;
		}
		msg(">>> '$_'\n");
		parseRetLine($comm, $_, $hideout);
	}
	return; # undef - quit server
}

#}}}

###### main routine

### parse args {{{
if (@ARGV == 0) {
	print "Usage: symsvr {repo} [:{instance_no=0}]
e.g.
  symsvr 1.repo.gz
  symsvr myprj.gz :1

Run as client:
  symsvr -c {cmd} [:{instance_no=0}]
e.g.
  symsvr -c \"f dbm\" :1
";
	exit;
}

my $param;
for (@ARGV) {
	if (/^:(\d+)/) {
		my $p = $1 +0;
		if ($p < 1000) {
			$INST_NO = $p;
		}
		else {
			$ENV{TCP_PORT} = $p;
		}
	}
	elsif ($_ eq '-c') {
		$g_isclient = 1;
	}
	else {
		$param = $_;
	}
}

if ($g_isclient) {
	runClient($param || '');
	exit;
}

my $repo = $param || '1.repo.gz';
unless (-f $repo) {
	print "*** cannot find repo file '$repo'\n";
	exit;
}
#}}}

	pipe(MAIN_RD, TGT_WR);
	pipe(TGT_RD, MAIN_WR);

	my $cmd = "$SYMFIND $repo";

	$g_tgtpid = fork;
	if ($g_tgtpid == 0) {  # TGT
		close MAIN_RD;
		close MAIN_WR;

		open(STDERR, ">&TGT_WR")     || die "Can't redirect stderr";
		open(STDOUT, ">&TGT_WR")     || die "Can't redirect stdout";
		open(STDIN, "<&TGT_RD")    || die "Can't redirect stdin";

		select TGT_WR;
		$| = 1;
		select STDERR;
		$| = 1;
		select STDOUT;
		$| = 1;

		$ENV{SYM_SVR} =1;
		system($cmd);

		close STDERR;
		close STDOUT;
		exit;
	}

	close TGT_RD;
	close TGT_WR;

	select MAIN_WR;
	$| = 1;

	my $comm = CommInet->new();
	execCmd(undef, undef); # just process init output
	msg ("=== server is ready.\n", 1);
	while(1)
	{
		local $_ = $comm->get() || '';
		mychop($_);
		if (/\.debug=(\d)/ ) {
			$DEBUG = $1;
			next;
		}

		my $hideout = 0; # s/^@//;
		my $rv = execCmd($comm, $_, $hideout);
		last unless defined $rv;
	}

# vim: set foldmethod=marker :
