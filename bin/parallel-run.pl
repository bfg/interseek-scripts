#!/usr/bin/perl

# Flexible parallel running script.
#
# Copyright (C) 2010 Brane F. Gracnar
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;

# use efficient sigchld trapper
sub POE::Kernel::USE_SIGCHLD () { 1 }

use POE;
use IO::File;
use IO::Handle;
use Getopt::Long;
use File::Basename;
use POE::Wheel::Run;
use POE::Filter::Line;
use POE::Filter::Stream;

use POSIX qw(strftime);
use Text::ParseWords qw(shellwords);

#########################################################
#                      GLOBALS                          #
#########################################################

my $key_file = undef;
my $command = "";
my $proc_restart = 0;
my $proc_concurrency = 20;
my $log_file_pattern = "";
my $log_stream = 1;
my $common_msglog = 1;
my $verbose = 0;
my $required_exit_code = 0;
my $stderr = 0;
my $re_stderr = undef;
my $re_stdout = undef;
my $log_msg_prefix = '[%Y/%m/%d %H:%M:%S] (%{key}): ';

#########################################################
#                      FUNCTIONS                        #
#########################################################

my $MYNAME = basename($0);
my $VERSION = "0.11";

my @keys = ();		# array of keys

my $w_proc = {};	# process wheels
my $pid2key = {};	# pid => key dict
my $wid2key = {};	# wheel id => key dict
my $wid2pid = {};	# wheel id => $pid
my $pid2wid = {};   # pid => wheel id dict

my $_re_stderr = undef;	# compiled stderr regex
my $_re_stdout = undef; # compiled stdout regex
my $_no_proc = 0;

sub read_keys {
	my ($file) = @_;
	# read stdin in case of undefined file
	$file = "-" unless (defined $file);
	
	# open file or stdin
	my $fd = undef;
	if ($file eq '-') {
		# try to open stdin
		$fd = IO::Handle->new();
		unless ($fd->fdopen(fileno(STDIN), 'r')) {
			die "Unable to open stdin for reading: $!\n";
		}
	} else {
		# try to open file
		$fd = IO::File->new($file, 'r');
		die "Unable to open file '$file': $!\n" unless (defined $fd);
	}

	# read file
	while (<$fd>) {
		# trim line
		$_ =~ s/^\s+//g;
		$_ =~ s/\s+$//g;
		# skip comments & empty lines
		next if ($_ =~ m/^#/);
		next unless (length($_) > 0);

		# assign as key
		push(@keys, $_);
	}
	
	return 1;
}

sub msg_verbose {
	return 1 unless ($verbose);
	print STDERR strftime("[%Y/%m/%d %H:%M:%S] ", localtime(time())), join("", @_), "\n";
}

sub msg_error {
	print STDERR strftime("[%Y/%m/%d %H:%M:%S] ", localtime(time())), "ERROR: ", join("", @_), "\n";
}

sub my_which {
	my ($prog) = @_;
	return undef unless (defined $prog && length($prog));
	return $prog if (-f $prog && -x $prog);

	foreach my $dir (split(/\s*[;:]+\s*/, $ENV{PATH}), '/sbin', '/usr/sbin', '/usr/local/sbin') {
		my $x = $dir . '/' . $prog;
		return $x if (-f $x && -x $x);
	}

	return undef;
}

sub wheel_create {
	my ($key) = @_;
	
	# compute command name
	my $cmd = command_compute($key);
	
	# try to resolve full-program name
	my @x = shellwords($cmd);
	my $p = shift(@x);
	my $prog = my_which($p);
	unless (defined $prog) {
		msg_error("Unable to find program $p in PATH.");
		return 0;
	}
	unshift(@x, $prog);

	# create process wheel
	msg_verbose("Invoking command: '$cmd'");
	my $wheel = eval {
		POE::Wheel::Run->new(
			Program => \ @x,
			StdoutEvent => "proc_stdout",
			StderrEvent => "proc_stderr",
			CloseEvent => "proc_close",
			ErrorEvent => "proc_error",
			StdioFilter => ($log_stream) ? POE::Filter::Stream->new() : POE::Filter::Line->new(),
		);
	};

	# check for injuries
	if ($@) {
		msg_error("Error spawning command: $@");
		return 0;
	}
	unless (defined $wheel) {
		msg_error("Error spawning command: undefined wheel: $!");
		return 0;
	}
	
	# increment number of running processes
	$_no_proc++;

	my $pid = $wheel->PID();
	# $poe_kernel->sig("CHLD", "proc_chld");
	$poe_kernel->sig_child($pid, 'proc_chld');
	my $wid = $wheel->ID();
	msg_verbose("Command spawned as pid $pid, wheel id $wid");

	# save the wheel && do some dictionary work
	$w_proc->{$wid} = [ $wheel, $cmd ];
	$wid2pid->{$wid} = $pid;
	$wid2key->{$wid} = $key;
	$pid2wid->{$pid} = $wid;

	return 1;
}

sub _start {
	if ($proc_concurrency > 0 ) {
		my $i = 0;
		while ($i < $proc_concurrency) {
			my $key = shift(@keys);
			last unless (defined $key);
			wheel_create($key);
			$i++;
		}
	} else {
		foreach my $key (@keys) {
			# create run wheel for each ip
			wheel_create($key);
		}
	}
}

sub proc_stdout {
	my ($kernel, $line, $wid) = @_[KERNEL, ARG0, ARG1];
	# print "proc_stdout $wid: $line";
	my $key = $wid2key->{$wid};
	return 0 unless (defined $key);
	if (defined $_re_stdout) {
		return 1 unless ($line =~ $_re_stdout);
	}
	msg_write($key, $line);
}

sub proc_stderr {
	my ($line, $wid) = @_[ARG0, ARG1];
	# print "proc_stderr $wid: $line";
	return 1 unless ($stderr);
	my $key = $wid2key->{$wid};
	return 0 unless (defined $key);
	if (defined $_re_stderr) {
		return 1 unless ($line =~ $_re_stderr);
	}
	msg_write($key, $line);
}

sub msg_write {
	my ($key, $str) = @_;
	my $pfx = $log_msg_prefix;
	if (defined $pfx && length $pfx) {
		$pfx = strftime($log_msg_prefix, localtime(time()));
		$pfx =~ s/%{key}/$key/g;
	}

	my $msg = $pfx . $str;
	
	# print to common stdout?
	if ($common_msglog) {
		print $msg, "\n";
	}
	
	# write to custom log file?
	my $file = $log_file_pattern;
	return 1 unless (defined $file && length($file) > 0);
	
	# format filename
	$file =~ s/%{key}/$key/g;
	$file = strftime($file, localtime(time()));
	
	# open file
	my $fd = undef;
	if ($file eq '-') {
		$fd = IO::Handle->new();
		unless ($fd->fdopen(fileno(STDOUT), 'w')) {
			$fd = undef;
		}
	} else {
		$fd = IO::File->new($file, 'a');
	}
	unless (defined $fd) {
		msg_error("Unable to open file '$file' for appending: $!");
		return 1;
	}
	
	# write message
	print $fd $msg, "\n";
}

sub log_wheel_get {
	my ($key) = @_;
	return undef unless (defined $key);
	return undef;
}

sub proc_close {
	my ($kernel, $wid) = @_[KERNEL, ARG0];
	my $ip = $wid2key->{$wid};
	return 0 unless (defined $ip);
}

sub wheel_destroy {
	my ($wid, $pid) = @_;
	return 0 unless (defined $wid);
	unless (defined $pid && $pid > 0) {
		$pid = $wid2pid->{$wid};
	}
	msg_verbose("Destroying wheel $wid for pid $pid");

	# destroy process wheel
	delete($w_proc->{$wid}) if (exists($w_proc->{$wid}));

	# destroy dicts
	delete($wid2key->{$wid}) if (exists($wid2key->{$wid}));
	delete($pid2wid->{$pid}) if (defined $pid);
	delete($wid2pid->{$wid});

	return 1;
}

sub command_compute {
	my ($key) = @_;
	return undef unless (defined $key);
	my $str = $command;
	$str =~ s/%{key}/$key/g;
	return $str;
}

sub proc_chld {
	my ($kernel, $name, $pid, $exit_val) = @_[KERNEL, ARG0 .. $#_];
	# find wid
	my $wid = (exists $pid2wid->{$pid}) ? $pid2wid->{$pid} : undef;
	return 0 unless (defined $wid);
	
	# decrement number of running processes
	$_no_proc--;

	my $err = check_exit_code($exit_val);
	if (defined $err) {
		my $cmd = $w_proc->{$wid}->[1];
		msg_error("Error running command '$cmd': ", $err);
	}

	# find key...
	my $key = (defined $wid) ? $wid2key->{$wid} : undef;

	# destroy the wheel...
	wheel_destroy($wid, $pid);
	
	# restart proces or create new ones if needed
	if ($proc_restart) {
		wheel_create($key) if (defined $key);
	}
	# next proc? in line?
	if ($_no_proc < $proc_concurrency) {
		wheel_create(shift(@keys)) if (@keys);
	}
}

sub proc_error {
	my ($operation, $errno, $errstr, $wid) = @_[ARG0..ARG3];
	return 1 if ($errno == 0);
	msg_error("Error $errno accoured while running operation $operation on wheel $wid: $errstr");
	# destroy the wheel
	#wheel_destroy($wid);
}

sub regex_compile {
	my ($str) = @_;
	my $re_str = undef;
	my $flags = undef;
	if ($str =~ m/^\/(.+)\/([imosx]{0,5})$/) {
		$re_str = $1;
		$flags = $2;
	} else {
		die "Invalid regex pattern '$str' syntax: not a /REGEX/flags syntax.\n";
	}
	
	# try to compile regex
	my $re = undef;
	eval {
		$re = qr/(?$flags:$re_str)/;
	};
	if ($@) {
		msg_error("Error compiling regex pattern 'str': $@");
		exit 1;
	}
	
	# return compiled regex
	return $re;
}

# returns undef if everything ok, otherwise error string
sub check_exit_code {
	my ($rv) = @_;
	# exit code checks disabled?
	return undef if ($required_exit_code < 0);

	my $result = undef;
	return "Undefined exit code." unless (defined $rv);
	
	if ($rv == -1) {
		$result = "Unable to execute: $!"
	}
	elsif ($rv & 127) {
		$result = sprintf(
			"Program died with signal %d, %s coredump.",
			($rv & 127),
			($rv & 128) ? "with" : "without"
		);
	}
	else {
		my $code = $rv >> 8;
		if ($code != $required_exit_code) {
			$result = "Program exited with exit code $code.";
		}
	}

	
	return $result;
}

sub printhelp {
	no warnings;
	print <<EOF
Usage: $MYNAME [OPTIONS] -c "command --arg=%{key}" [<key> <key2> ...]

This script concurrently runs multiple commands and gathers output.

OPTIONS:
  -f    --key-file=FILE    Sets file containing keys (Default: "$key_file")
  -c    --command          Command pattern (Default: "$command")
                           NOTE: stdout/stderr redirection is NOT supported.
  
  -l    --log-pattern=STR  Write command output to specified file pattern
                           (Default: "$log_file_pattern")
                           Zero-length pattern disables per-process output logging.
                           NOTE: File pattern supports strftime(3) placeholders
                           NOTE: Any %{key} in pattern will be replaced by
                                 key of current process.
                           EXAMPLE: "/tmp/log.%{key}.%Y%m%d"
  
  -r    --restart          Restart invoked process when exits (Default: $proc_restart)
                           NOTE: this option is mutualy exclusive with option -n
                         
  -n    --concurrency=N    Sets maximum number of concurrently running
                           processes (Default: $proc_concurrency)
                           NOTE: this option is mutualy exclusive with option -r
                           NOTE: 0 == no limit, could overload your system
        
  --no-stderr              Ignore program stderr
  --stdout-re=/REGEX/flags Stdout output regex
  --stderr-re=/REGEX/flags Stderr output regex
  
  --log-msg-pfx=PATT       Log message prefix (Default: "$log_msg_prefix")
  --no-log-stream          Perform per-line spawned program logging
  --log-per-line           (Don't use this option unless you know what you're doing.)
  
  --no-common-log          Don't print output of all subprocesses to
                           script's stdout.
  -e    --exit-code=INT    Require specified exit code (Default: $required_exit_code)
                           NOTE: Value of -1 disables exit code checking.

  -v    --verbose          Verbose execution
  -V    --version          Prints script version
  -h    --help             This help message

EXAMPLES:
  # concurrently ping 5 ips only once
  $MYNAME -c "ping -c5 -W1 %{key}" 192.168.1.{1,2,3,4,5}

  # continuously ping 5 ips at the same time
  $MYNAME -c "ping -c5 -W1 %{key}" -r 192.168.1.{1,2,3,4,5}
  
  # continuously ping 5 ips at the same time,
  # write per process logging, ignore stderr & filter stdout
  $MYNAME -c "ping -c5 -W1 %{key}" -r \\
                                   --no-stderr \\
                                   --stdout-re='/icmp_seq|transmitted/' \\
                                   -l "/tmp/pinglog.%{key}.%Y%m%d" \\
                                   192.168.1.{1,2,3,4,5}
EOF
;
}

#########################################################
#                         MAIN                          #
#########################################################

# parse command line
Getopt::Long::Configure("bundling", "permute", "bundling_override");
my $g = GetOptions(
	'f|key-file=s' => sub {
		die unless (read_keys($_[1]));
	},
	'c|command=s' => \ $command,
	'l|log-pattern=s' => \ $log_file_pattern,
	'r|restart!' => sub {
		if ($_[1]) {
			$proc_concurrency = 0;
			$proc_restart = 1;	
		} else {
			$proc_restart = 0;
		}
	},
	'n|concurrency=i' => sub {
		$proc_concurrency = $_[1];
		$proc_restart = 0;
	},
	'stderr!' => \ $stderr,
	'stderr-re=s' => sub {
		$_re_stderr = regex_compile($_[1]);
	},
	'stdout-re=s' => sub {
		$_re_stdout = regex_compile($_[1]);		
	},
	'log-msg-pfx:s' => \ $log_msg_prefix,
	'log-stream!' => \ $log_stream,
	'log-per-line' => sub { $log_stream = 0 },
	'common-log!' => \$common_msglog,
	'e|exit-code=i' => \ $required_exit_code,
	'v|verbose!' => \ $verbose,
	'V|version' => sub {
		print sprintf("%s %-.2f\n", $MYNAME, $VERSION);
		exit 0;
	},
	'h|help' => sub {
		printhelp();
		exit 0;
	},
);
unless ($g) {
	die "Invalid command line. Run $MYNAME --help for instructions.\n";
}

$proc_concurrency = int($proc_concurrency);

# check parameters...
if ($proc_restart && $proc_concurrency) {
	die "Parameters --restart and --concurrency are mutual exclusive! Run $MYNAME --help for instructions.\n";
}
unless (defined $command && length($command) > 0) {
	die "Undefined command pattern.\n";
}

# add additional key from command line...
push(@keys, @ARGV);

# force autoflush
$| = 1;

# create poe session
POE::Session->create(
	inline_states => {
		_start => \ &_start,
		proc_stdout => \ &proc_stdout,
		proc_stderr => \ &proc_stderr,
		proc_close => \ &proc_close,
		proc_error => \ &proc_error,
		proc_chld => \ &proc_chld,
	}
);

# run poe kernel
POE::Kernel->run();

# EOF
