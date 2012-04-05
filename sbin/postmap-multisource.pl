#!/usr/bin/perl

# Copyright (c) 2008, Brane F. Gracnar
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the Brane F. Gracnar nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY Brane F. Gracnar ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <copyright holder> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#################################################
#                  FUNCTIONS                    #
#################################################

package DataSource;

use strict;
use warnings;

my $Error = "";

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};

	$self->{_error} = "";

	bless($self, $class);
	$self->clearParams();
	$self->setParams(@_);
	return $self;
}

sub getError {
	my ($self) = @_;
	return $Error unless (ref($self));
	return $self->{_error};
}

sub setParams {
	my $self = shift;
	while (defined (my $key = shift(@_)) && defined (my $v = shift(@_))) {
		next if ($key =~ m/^_/);
		$self->{$key} = $v;
	}

	return 1;
}

sub clearParams {
	my ($self) = @_;

	return 1;
}

sub getDriverOpt {
	my ($self) = @_;
	my $c = {};
	foreach (keys %{$self}) {
		if ($_ !~ m/^_/) {
			$c->{$_} = $self->{$_};
		}
	}

	return $c;
}

sub getDrivers {
	my @r = ("LDAP", "DBI");
	return sort @r;
}

sub factory {
	shift if ($_[0] eq __PACKAGE__);
	$Error = "";
	my ($driver, %opt) = @_;
	unless ($driver) {
		$Error = "Unspecified driver.";
		return undef;
	}
	
	# create object
	my $class = __PACKAGE__ . "::" . $driver;
	my $obj = undef;
	eval "require $class";
	eval {
		$obj = $class->new(%opt);
	};
	
	if ($@ || ! defined $obj) {
		$Error = "Error initializing object: $@ $!";
		return undef;
	}

	return $obj;
}

sub get {
	my ($self) = @_;
	return $self->_get();
}

sub _get {
	my ($self) = @_;
	$self->{_error} = "Method _get() is not implemented by the base class.";
	return undef;
}

package DataSource::LDAP;

use strict;
use warnings;

use Net::LDAP;

use vars qw(@ISA);
@ISA = qw(DataSource);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new(@_);

	$self->{_error} = "";

	bless($self, $class);
	$self->clearParams();
	$self->setParams(@_);
	return $self;
}

sub clearParams {
	my ($self) = @_;
	$self->{host} = "localhost";
	$self->{port} = 389;
	$self->{tls} = 0;
	$self->{timeout} = 3;
	$self->{search_base} = "";
	$self->{bind_dn} = "";
	$self->{bind_pw} = "";
	$self->{search_scope} = "one";
	$self->{search_filter} = "(objectClass=nisMailAlias)";
	$self->{result_attribute} = "rfc822MailMember";
	$self->{debug} = 0;
}

sub _get {
	my ($self) = @_;
	my $result = [];
	
	my $conn = $self->_connect();
	return undef unless ($conn);

	my $r = $conn->search(
		base => $self->{search_base},
		scope => $self->{search_scope},
		filter => $self->{search_filter},
		attrs => [ $self->{result_attribute} ],
	);

	if ($r->code()) {
		$self->{_error} = "Error performing LDAP search: " . $r->error();
		return undef;
	}
	
	# read entries
	foreach my $e ($r->entries()) {
		next unless (defined $e);
		my $dn = $e->dn();
		$dn =~ s/^[^=]+=//g;
		$dn =~ s/,.*//g;

		my $x = {
			key => $dn,
			value => [ $e->get($self->{result_attribute}, asref => 1) ]
		};

		push(@{$result}, $x);
	}

	return $result;
}

sub _connect {
	my ($self) = @_;
	my $c = undef;
	$c = Net::LDAP->new(
		$self->{host},
		port => $self->{port},
		timeout => $self->{timeout},
		debug => $self->{debug},
	);
	
	unless ($c) {
		$self->{_error} = "Error connecting to ldap server '$self->{host}:$self->{port}': $!";
		return undef;
	}
	
	# tls?
	if ($self->{tls}) {
		# try to start tls...
		unless ($c->start_tls()) {
			$self->{_error} = "Unable to start TLS: " . $c->error();
			return undef;
		}
	}
	
	# auth?
	if (defined $self->{bind_dn} && length($self->{bind_dn}) > 0) {
		unless ($c->bind($self->{bind_dn}, password => $self->{bind_pw})) {
			$self->{_error} = "Unable to bind($self->{bind_dn}): " . $c->message();
			return undef;
		}
	}

	# connection ok
	return $c;
}

package DataSource::DBI;

use strict;
use warnings;

use DBI;

use vars qw(@ISA);
@ISA = qw(DataSource);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new(@_);

	$self->{_error} = "";

	bless($self, $class);
	$self->clearParams();
	$self->setParams(@_);
	return $self;
}

sub clearParams {
	my ($self) = @_;
	$self->{dsn} = "localhost";
	$self->{username} = 389;
	$self->{password} = 0;
	$self->{sql} = "SELECT name from blah blah blah...";
}

sub _get {
	my ($self) = @_;
	my $result = [];
	
	my $conn = $self->_connect();
	return undef unless ($conn);
	
	use Data::Dumper;
	
	my $ref = $conn->selectall_arrayref($self->{sql});
	
	unless (defined $ref) {
		$self->{_error} = "Error executing SQL '$self->{sql}': " . $conn->errstr();
		return undef;
	}

	my %h = ();
	foreach (@{$ref}) {
		my $key = $_->[0];
		my $val = $_->[1];
		my @vals = split(/\s*,\s*/, $val);
		map {
			$_ =~ s/^\s+//g;
			$_ =~ s/\s+$//g;
		} @vals;
		push(@{$h{$key}}, @vals);
		# print "GOT: $key => ", join(", ", @vals), "\n";
	}
	
	foreach (keys %h) {
		my $e = {
			key => $_,
			value => [ @{$h{$_}} ],
		};
		push(@{$result}, $e);
	}

	return $result;
}

sub _connect {
	my ($self) = @_;
	my $conn = DBI->connect(
		$self->{dsn},
		$self->{username},
		$self->{password},
		{
			RaiseError => 0,
			PrintError => 0,
		}
	);
	
	unless (defined $conn) {
		$self->{_error} = "Unable to connect to data source '$self->{dsn}': " . DBI->errstr();
		return undef;
	}
	
	return $conn;
}

package main;

use strict;
use warnings;

use IO::File;
use File::Spec;
use File::Copy;
use File::Path;
use Sys::Syslog;
use Digest::MD5;
use Getopt::Long;
use Sys::Hostname;
use File::Basename;
use POSIX qw(strftime);
use File::Temp qw(tempfile);

use constant TYPE_POSTALIAS => 0;
use constant TYPE_POSTMAP => 1;

#################################################
#                   GLOBALS                     #
#################################################

my $postmap = my_which("postmap");
my $postalias = my_which("postalias");
my $driver = "LDAP";
my %driver_opt = ();
my $owner = "";
my $group = "";
my $perm = "0644";
my $type = TYPE_POSTALIAS;
my $verbose = 0;
my $quiet = 0;

#################################################
#                  FUNCTIONS                    #
#################################################
my $MYNAME = basename($0);
my $VERSION = 0.10;
my $_Error = "";

sub msg_info {
	print STDERR "INFO:  ", join("", @_), "\n" unless ($quiet);
	msg_log(@_);
}

sub msg_err {
	print STDERR "ERROR: ", join("", @_), "\n";
	msg_log("ERROR: ", @_);	
}

sub msg_verb {
	print STDERR "VERBOSE: ", join("", @_), "\n" if ($verbose && ! $quiet);
	msg_log("VERBOSE: ", @_);
}

sub msg_fatal {
	print STDERR "FATAL: ", join("", @_), "\n";
	msg_log("FATAL: ", @_);
	exit 1;
}

sub msg_debug {
	print STDERR "DEBUG: ", join("", @_), "\n";
}

sub msg_log {
	openlog($MYNAME, "ndelay,nofatal,pid", "mail");
	syslog("info", join("", @_));
	closelog();
}

sub my_which {
	my ($cmd) = @_;
	foreach (split(/[:;]+/, $ENV{PATH} . ":/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin")) {
		my $bin = File::Spec->catfile($_, $cmd);
		return $bin if (-f $bin && -x $bin);
	}

	return undef;
}

sub config_read_file {
	my ($file) = @_;
	my $c = {};
	unless (defined $file && -f $file && -r $file) {
		$_Error = "Invalid file argument: $!";
		return undef;
	}

	my $fd = IO::File->new($file, 'r');
	unless (defined $fd) {
		$_Error = "Unable to open file '$file': $!";
		return undef;
	}
	
	my $in_section = 0;

	# read file...
	while (<$fd>) {
		$_ =~ s/#.*//g;
		$_ =~ s/^\s+//g;
		$_ =~ s/\s+$//g;
		next unless (length($_) > 0);
		
		if ($_ =~ m/^\[\w+\]$/) {
			$in_section = 1;
			next;
		}

		my ($key, $value) = split(/\s*=\s*/, $_, 2);
		next unless (defined $value);
			
		# remove double "" from the value
		$value =~ s/^\s+//g;
		$value =~ s/\s+$//g;
		$value =~ s/^\"+//g;
		$value =~ s/\"+$//g;
		
		if (! $in_section) {
			my $str = "\$$key = \"$value\";";
			# print "EVAL: '$str'\n";
			eval $str;
		} else {
			# print "Setting driver key '$key' => '$value'\n";
			$driver_opt{$key} = $value;
		}
	}

	$fd = undef;

	return $c;
}

sub printhelp {
	print STDERR "Usage: $MYNAME [OPTIONS] <file>\n\n";
	print STDERR "This script fetches data from SQL/LDAP backend, writes postfix/sendmail\n";
	print STDERR "postmap(5) or aliases(5) formatted file and runs postmap(1) or postalias(1)\n";
	print STDERR "command to create local copy of network located MTA alias/map database.\n";
	print STDERR "\n";
	print STDERR "OPTIONS:\n";
	print STDERR "  -c    --config              Load specified configuration file\n";
	print STDERR "        --default-config      Prints default configuration file\n";
	print STDERR "\n";
	print STDERR "  -M    --postmap             Path to postmap(8) binary (Default: \"$postmap\")\n";
	print STDERR "  -A    --postalias           Path to postalias(8) binary (Default: \"$postalias\")\n";
	print STDERR "\n";
	print STDERR "  -D    --driver              Use specified driver (Default: \"$driver\")\n";
	print STDERR "  -O    --driver-opt KEY=VAL  Set driver option\n";
	print STDERR "\n";
	print STDERR "  -u    --owner               File owner (Default: \"$owner\")\n";
	print STDERR "  -g    --group               File group (Default: \"$group\")\n";
	print STDERR "  -p    --perm                File permission (Default: \"$perm\")\n";
	print STDERR "\n";
	print STDERR "  -v    --verbose             Verbose execution\n";
	print STDERR "  -q    --quiet               Quiet execution\n";
	print STDERR "  -V    --version             Prints script version\n";
	print STDERR "  -h    --help                This help message\n";
}

sub default_config_print {
	no warnings;
	my @drivers = DataSource->getDrivers();
	print "#\n";
	print "# $MYNAME configuration\n";
	print "#\n";
	print "\n";
	print "# Source driver\n";
	print "#\n";
	print "# Possible values: ", join(", ", @drivers), "\n";
	print "# Type: string\n";
	print "# Default: \"$driver\"\n";
	print "driver = \"$driver\"\n";
	print "\n";
	
	print "# File owner\n";
	print "# Type: string\n";
	print "# Default: undefined\n";
	print "# owner = \"$owner\"\n";
	print "\n";

	print "# File group\n";
	print "# Type: string\n";
	print "# Default: \"$group\"\n";
	print "# group = root\n";
	print "\n";

	print "# File permission\n";
	print "# Type: string\n";
	print "# Default: $perm\n";
	print "# perm = $perm\n";
	print "\n";
	
	print "# Path to postfix commands\n";
	print "# Type: string\n";
	print "# postmap = $postmap\n";
	print "# postalias = $postalias\n";
	print "\n";

	print "# Execution verboseness\n";
	print "# Type: boolean\n";
	print "# Default: 0\n";
	print "# quiet = $quiet\n";
	print "# verbose = $verbose\n";
	print "\n";

	foreach my $d (@drivers) {
		my $obj = DataSource->factory($d);
		next unless (defined $obj);
		my $c = $obj->getDriverOpt();
		next unless (defined $obj);
		print "#\n";
		print "# $d driver options\n";
		print "#\n";
		print "#[$d]\n";

		foreach (sort keys %{$c}) {
			print "#\t$_ = $c->{$_}\n";
		}
		print "\n";
	}

	print "\n";
	print "# EOF\n";
}

sub postfile_write {
	my ($data, $fd, %opt) = @_;
	unless (defined $data) {
		$_Error = "Undefined data";
		return 0;
	}
	unless (defined $fd && fileno($fd) > 0) {
		$_Error = "Undefined filehandle";
	}

	# print header
	print $fd "#\n";
	printf $fd "# Generated by: %s %-.2f\n", $MYNAME, $VERSION;
	print $fd "# Generated on: ", strftime("%Y/%m/%d %H:%M:%S %Z", localtime(time())), "\n";
	print $fd "#\n";
	print $fd "# Source \"$driver\" configuration:\n";
	foreach (keys %opt) {
		my $val = $opt{$_};
		$val = '********' if ($_ =~ m/^pass/ || $_ =~ m/_?pw$/ || $_ =~ m/_?pass(word)?$/);
		print $fd "#    $_ = $val\n";
	}
	print $fd "#\n";
	print $fd "\n";

	my $kv_delim = ($type == TYPE_POSTALIAS) ? ":\t" : "\t";

	# write output...
	foreach (@{$data}) {
		print $fd $_->{key}, $kv_delim, join(", ", @{$_->{value}}), "\n";
	}
	
	# print footer
	print $fd "\n# EOF\n";

	return 1;
}

sub check_exit_val {
	my ($val) = @_;
	my $r = 0;

	if ($val == -1) {
		$_Error = "Failed to execute: $!\n";
	}
	elsif ($val & 127) {
		$_Error = sprintf("Program died with signal %d, %s coredump.", ($val & 127), ($val & 128) ? "with" : "without");
	}
	else {
		my $x = $val >> 8;
		if ($x != 0) {
			$_Error = "Program exited with value $x.";
		} else {
			$r = 1;
		}
	}

	return $r;
}

sub md5 {
	my ($file) = @_;
	my $fd = IO::File->new($file, 'r');
	return undef unless (defined $fd);
	my $ctx = Digest::MD5->new();
	$ctx->addfile($fd);
	return $ctx->hexdigest();
}

sub md5_textfile {
	my ($file) = @_;
	my $fd = IO::File->new($file, 'r');
	return undef unless (defined $fd);
	my $ctx = Digest::MD5->new();

	# read file and weed out comments...
	while (<$fd>) {
		$_ =~ s/#.*//g;
		$_ =~ s/^\s+//g;
		$_ =~ s/\s+$//g;
		next unless (length($_) > 0);
		$ctx->add($_);		
	}
	
	$fd = undef;
	return $ctx->hexdigest();
}

sub postmap {
	my ($file) = @_;
	unless (defined $file && -f $file && -r $file) {
		no warnings;
		$_Error = "Invalid file: '$file'";
		return 0;
	}

	msg_verb("Running: '$postmap $file'.");
	system($postmap, $file);
	
	return check_exit_val($?);
}

sub postalias {
	my ($file) = @_;
	unless (defined $file && -f $file && -r $file) {
		no warnings;
		$_Error = "Invalid file: '$file'";
		return 0;
	}
	
	msg_verb("Running: '$postalias $file'.");
	system($postalias, $file);

	return check_exit_val($?);
}

sub run {
	my ($file) = @_;
	# check command availability
	unless (defined $postmap && -f $postmap && -x $postmap) {
		no warnings;
		$_Error = "Invalid or undefined postmap command: '$postmap'.";
		return 0;
	}
	unless (defined $postalias && -f $postalias && -x $postalias) {
		no warnings;
		$_Error = "Invalid or undefined postalias command: '$postalias'.";
		return 0;
	}

	# 0. get data source
	my $source = DataSource->factory($driver, %driver_opt);
	unless (defined $source) {
		$_Error = "Error initializing data source: " . DataSource->getError();
		return 0;
	}

	# 1. fetch data
	my $data = $source->get();
	unless (defined $data) {
		$_Error = $source->getError();
		return 0;
	}

	# 2. write data to TXT file
	my ($tmpfd, $fname) = tempfile();
	unless (defined $tmpfd) {
		$_Error = "Error creating temporary file: $!";
		return 0;
	}
	unless (postfile_write($data, $tmpfd, %driver_opt)) {
		return 0;
	}
	
	unless (close($tmpfd)) {
		$_Error = "Error closing tmp file '$fname': $!";
		return 0;
	}
	
	# 3. update database file
	if ($type == TYPE_POSTALIAS) {
		postalias($fname);
	}
	elsif ($type == TYPE_POSTMAP) {
		postmap($fname);
	}
	else {
		msg_fatal("Invalid output type: $type");
	}
	
	my $fname_db = $fname . ".db";
	my $file_db = $file . ".db";
	
	# check file digests...
	my $digest_old = md5_textfile($file);
	my $digest_new = md5_textfile($fname);
	
	my $do_install = (! defined $digest_old || $digest_old ne $digest_new);
	
	# install if necessary...
	if ($do_install) {
		my $parent = dirname($file);
		unless (-d $parent) {
			unless (mkpath($parent)) {
				$_Error = "Error creating parent directory '$parent': $!";
				return 0;
			}
		}

		msg_info("Installing '$file'.");
		unless (move($fname, $file)) {
			$_Error = "Error moving file '$fname' => '$file': $!";
			return 0;
		}
		msg_info("Installing '$file_db'.");
		unless (move($fname_db, $file_db)) {
			$_Error = "Error moving file '$fname_db' => '$file_db': $!";
			return 0;
		}

		# chown
		if (length($owner) > 0 || length($group) > 0) {
			msg_info("Setting file ownership to '$owner:$group'");
			my (undef, undef, $uid, $gid) = getpwnam($owner);
			unless (defined $uid) {
				$_Error = "Unable to resolve user '$owner' uid: $!";
				return 0;				
			}
			if (length($group) > 0) {
				$gid = getgrnam($group);
				unless (defined $gid) {
					$_Error = "Unable to resolve group '$group' gid: $!";
					return 0;
				}
			}

			unless (chown($uid, $gid, $file)) {
				$_Error = "Unable chown($uid, $gid) '$file': $!";
				return 0;
			}
			unless (chown($uid, $gid, $file_db)) {
				$_Error = "Unable chown($uid, $gid) '$file_db': $!";
				return 0;				
			}
		}

		# chmod
		if (length($perm) > 0) {
			msg_info("Setting file permissions to '$perm'.");
			unless (chmod(oct($perm), $file)) {
				$_Error = "Unable to change permissions on '$file': $!";
				return 0;
			}
			unless (chmod(oct($perm), $file_db)) {
				$_Error = "Unable to change permissions on '$file_db': $!";
				return 0;
			}
		}
	}
	# perform cleanup
	else {
		unless (unlink($fname)) {
			msg_warn("Error removing temporary file '$fname': $!");
		}
		unless (unlink($fname_db)) {
			msg_warn("Error removing temporary file '$fname_db': $!");
		}
	}

	return 1;
}

#################################################
#                    MAIN                       #
#################################################

# parse command line...
Getopt::Long::Configure("bundling", "permute", "bundling_override");
my $g = GetOptions(
	'c|config=s' => sub {
		unless (config_read_file($_[1])) {
			msg_fatal("Error parsing configuration file: $_Error");
		}
	},
	'default-config' => sub {
		default_config_print();
		exit 0;
	},
	'M|postmap=s' => \ $postmap,
	'A|postalias=s' => \ $postalias,
	'D|driver=s' => \ $driver,
	'O|driver-opt=s' => \ %driver_opt,
	'u|owner=s' => \ $owner,
	'g|group=s' => \ $group,
	'p|perm=s' => \ $perm,
	'q|quiet!' => \ $quiet,
	'v|verbose!' => \ $verbose,
	'V|version' => sub {
		printf("%s %-2.2f\n", $MYNAME, $VERSION);
		exit 0;
	},
	'h|help' => sub {
		printhelp();
		exit 0;
	}
);

unless ($g && @ARGV) {
	msg_fatal("Invalid command line options. Run $MYNAME --help for instructions.");
}

# how we were called?
if ($MYNAME =~ m/^postmap-/) {
	$type = TYPE_POSTMAP;
}
elsif ($MYNAME =~ m/^postalias-/) {
	$type = TYPE_POSTALIAS;
}
else {
	msg_fatal("This script should be named postmap-multisource.pl or postalias-multisource.pl");
}


my $r = run(@ARGV);
msg_err($_Error) unless ($r);

exit(! $r);

# EOF
