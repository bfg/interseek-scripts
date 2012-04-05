#!/usr/bin/perl

# Perl script for creation of useful container/webapp info PHP script
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

use IO::File;
use Getopt::Long;
use File::Basename;

my $MYNAME = basename($0);
my $VERSION = 0.10;

sub printhelp {
	print <<EOF
Usage: $MYNAME [OPTIONS]

This script creates nice version-info PHP script
and writes it to stdout.

OPTIONS:
  -o   --out     Output filename (default: stdout)

  -V   --version Prints script version and exits
  -h   --help    This help message
EOF
}

sub content_get {
	return q(
<?php

if (isset($_GET['info']) && $_GET['info'] == "1") {
	phpinfo();
	return 0;
}

$hostname = php_uname('n');

?>
<html>
<head>
<style type="text/css">
a, a:active {text-decoration: none; color: blue;}
a:visited {color: #48468F;}
a:hover, a:focus {text-decoration: underline; color: red;}
body {background-color: #F5F5F5; font-size: 80%;}
h4 {margin-bottom: 12px; font-size: 90%;}
table {margin-left: 12px; font-size: 100%;}
th, td { font: 90% monospace; text-align: left;}
th { font-weight: bold; padding-right: 14px; padding-bottom: 1px;}
td { font-size: 90%; padding-right: 14px;}
td.s, th.s {text-align: right; font-size: 90%;}
div.list { background-color: white; border-top: 1px solid #646464; border-bottom: 1px solid #646464; padding-top: 1px; padding-bottom: 1px;}
div.foot { font: 90% monospace; color: #787878; padding-top: 1px;}
</style>

<title><?php echo $hostname ?> :: Webapp/System info</title>
</head>

<body>
<!-- webapp version info -->
<b>Application version info</b>
<div class="list">
<?php
$dirs = array("include", "inc", "resource", ".", "..");
foreach ($dirs as $dir) {
	$file = $dir . "/version-local.txt";
	if (file_exists($file)) {
		echo "<b>$file</b><pre>\n";
		echo @file_get_contents($file);
		echo "</pre>\n";
	}
}
?>
</div>
<!-- webapp version info end -->
<!-- container info -->
<b>Container info</b>
<table summary="Container info" cellpadding="0" cellspacing="0">
	<thead>
	  <tr>
	 <th class="n">Key</th>
	 <th class="m">Value</th>

	  </tr>
	</thead>
	<tbody>
	  <tr><td class='n'>hostname</td><td class='m'><font color="red"><b><?php echo $hostname ?></b></font></td></tr>
	  <tr><td class='n'>ip address</td><td class='m'><font color="red"><b><?php echo $_SERVER["SERVER_ADDR"]; ?></b></font></td></tr>
	  <tr><td class='n'>server port</td><td class='m'><font color="red"><b><?php echo $_SERVER["SERVER_PORT"]; ?></b></font></td></tr>

	  <tr><td class='n'>date</td><td class='m'><b><?php echo date(DATE_RFC822); ?></b></td></tr>
	  <tr><td class='n'>server info</td><td class='m'><font color="red"><b><?php echo $_SERVER['SERVER_SOFTWARE'] ?></b></font></td></tr>
	  <tr><td class='n'>PHP version</td><td class='m'><b><?php echo phpversion(); ?></b></td></tr>
	</tbody>
	 </table>
<div class="list">
</div>
<!-- container info end -->
<iframe src='<?php echo $_SERVER['PHP_SELF'] . "?info=1"; ?>' frameborder="0" width="900" height="100%">
	<p>Your browser does not support iframes.</p>
</iframe>
</html>
);
}

my $dst = "-";

Getopt::Long::Configure("bundling", "permute", "bundling_override");
my $g = GetOptions(
	'o|out=s' => \$dst,
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

if (! defined $dst || $dst eq '-') {
	print content_get();
} else {
	my $fd = IO::File->new($dst, 'w');
	unless (defined $fd) {
		print STDERR "Unable to open file '$dst': $!\n";
		exit 1;
	}
	print $fd content_get();
}

exit 0;
