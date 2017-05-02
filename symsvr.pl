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
my $SYMSCAN = $ENV{SYMSCAN} || 'symscan.pl';
my $DEF_REPO = 'tags.repo.gz';

# update frequency: e.g. "2h" - 2hours; "30"/"30m" - 30min; "30s"
my $UPDATE = $ENV{P_UPDATE} || "2h";

###### global
my $g_tgtpid;
my $g_isclient = 0;
my $g_sig = ''; # update/quit/""
my $g_updateCmd;
my $g_repo;

###### toolkit {{{
sub mychop
{
	$_[0] =~ s/[ \r\n]+$//;
}

sub msg # ($msg, [$force=0])
{
	print STDERR $_[0] if $DEBUG || $_[1];
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
	msg("=== TCP_PORT=$p\n", 1) if !$g_isclient && !$g_sig;
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
		) or main::mydie("cannot connect to server (port=$TCP_PORT).");
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

# return: content or '<timeout>' for recv timeout
sub get # (\%opt={timeout})
{
	my $this = shift;
	my ($opt) = @_;
	my $sck;
	local $_;
	if ($opt->{timeout}) {
		$this->{sock}->timeout($opt->{timeout});
	}

	if ($this->{isclient}) {
		$sck = $this->{sock};
	}
	else {
		if ($this->{session}) {
			$this->{session}->close();
			delete $this->{session};
		}
		$sck = $this->{session} = $this->{sock}->accept();
		return '<timeout>' if !defined $sck; # timeout
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
sub showHelp
{
	print "Usage: symsvr [repo=$DEF_REPO] [:{instance_no=0}]
e.g.
  symsvr
  symsvr 1.repo.gz
  symsvr myprj.gz :1

Show help:
  symsvr -h
Run as client:
  symsvr -c {cmd} [:{instance_no=0}]
e.g.
  symsvr -c \"f dbm\" :1
";
}

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

sub logtm
{
	my @a = localtime(time);
	sprintf("%d/%02d/%02d %02d:%02d:%02d", $a[5]+1900,$a[4]+1, $a[3], $a[2], $a[1], $a[0]);
}

sub getUpdateTm # ()
{
	if ($UPDATE !~ /^(\d+)([hms])?$/) {
		$UPDATE = "2h"; # default: 2h
		return 2*3600; 
	}
	if (!defined($2) || $2 eq 'm') {
		return $1 * 60;
	}
	elsif ($2 eq 'h') {
		return $1 * 3600;
	}
	else {
		return $1 + 0;
	}
}

# ret: $thr
sub updateProc # ()
{
	use threads;
	use threads::shared;
	use File::stat;
	
	share($g_sig);

	my $thr = threads->create(sub {
		while (1) {
			my $sec = getUpdateTm();
			if ($sec == 0) {
				sleep(1);
				next;
			}
			my $diff = time() - stat($g_repo)->mtime;
			if ($diff < $sec) {
#				print "plan=$sec, diff=$diff, sleep " . ($sec - $diff) . "\n";;
				sleep($sec - $diff);
			}

			# scan
			system($g_updateCmd);
			print "=== Repo is updated.\n";
			$g_sig = 'update';
			# runClient("q");
			sleep($sec+1);
		}
	});
	$thr->detach();
	return $thr;
}
#}}}

###### main routine

### parse args {{{
my $params = '';
my @argv;
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
	elsif ($_ eq '-h') {
		showHelp();
		exit;
	}
	else {
		$params .= $_ . ' ';
		push @argv, $_;
	}
}
$g_repo = $argv[0] || $DEF_REPO;
chop $params if $params;

if ($g_isclient) {
	runClient($params);
	exit;
}

if (@argv == 0)
{
	unless (-f $DEF_REPO) {
		print "!!! no repo file. scan current folder ...\n";
		system("$SYMSCAN .");
	}
	unless (-f $DEF_REPO) {
		print "*** cannot find symbol repo: $DEF_REPO.";
		exit(-1);
	}
	$params = $DEF_REPO;
	push @argv, $DEF_REPO;
}

for my $repo (@argv) {
	unless (-f $repo) {
		print "*** cannot find repo file '$repo'\n";
		exit;
	}
}
#}}}

	my $cmd = "$SYMFIND $params";
	$g_updateCmd = "$SYMSCAN \"$g_repo\"";

	$ENV{SYM_SVR} =1;

	my $thrUpdate = updateProc();

	# Ctrl-C for graceful quit
	$SIG{INT} = sub {
		$g_sig = 'quit';
	};

again:
	use IPC::Open3;
	$g_tgtpid = open3(\*MAIN_WR, \*MAIN_RD, \*MAIN_RD, $cmd)
		or die("start symfind error: $!\n");
	select(MAIN_WR);    $| = 1; # make unbuffered

	my $comm = CommInet->new();
	execCmd(undef, undef); # just process init output
	msg ("=== [" . logtm() . "] server is ready. (update=$UPDATE)\n", 1);
	exit if !$IS_MSWIN && fork != 0;

	$g_sig = '';
	while(1)
	{
		local $_ = $comm->get({timeout=>1});
		last if $g_sig;
		next if $_ eq '<timeout>';
		mychop($_);
		if (/\.debug=(\d)/ ) {
			$DEBUG = $1;
			next;
		}
		if (/^u$/) {
			system($g_updateCmd);
			$comm->put("update done.\n");
			$g_sig = 'update';
			last;
		}

		my $hideout = 0; # s/^@//;
		my $rv = execCmd($comm, $_, $hideout);
		last unless defined $rv;
	}

	select STDOUT;
	$comm->destroy();
	print MAIN_WR "q\n"; # quit the symfind-process
	waitpid($g_tgtpid, 0);
	if ($g_sig eq 'update') {
		goto again;
	}

# vim: set foldmethod=marker :
