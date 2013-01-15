#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper; $Data::Dumper::Indent = 0;
use Getopt::Long;
use Cwd;
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile abs2rel splitpath);

# The default configuration.
my $default_config = {
	# generics
	'debug'			=> 0,
	'dump_config'	=> 0,
	'do_it'			=> 0,

	# files and paths
	'basedir'		=> '.',
	'linkdir'		=> './linked',
	'filelist'		=> '-',
	'currentdir'	=> getcwd(),
};

# The current configuration.
my $config = {}; 
%{$config} = %{$default_config};		# At start, it gets a copy of the default config.

# Command-line options.
my $options = {
	'd|debug'		=> \$config->{debug},
	'dump-config'	=> \$config->{dump_config},
	'y|do-it'		=> \$config->{do_it},
	'h|help'		=> sub {
		help();
		exit 0;
	},

	'S|basedir=s'	=> \$config->{basedir},
	'L|linkdir=s'	=> \$config->{linkdir},
};

=head2 cleanup()

	cleanup();

Cleans up the junk before exiting.
=cut
sub cleanup {
	chdir($config->{currentdir}) or error_msg("Could not chdir back to '$config->{currentdir}'");
	return 1;
}

=head2 debug_msg()

	debug_msg($message);
	$message	: a text message, scalar

Write a message if we are in debug mode.
=cut
sub debug_msg {
	my ($text) = @_;
	if ($config->{debug}) {
		print("[DEBUG] [" . (defined((caller(1))[3]) ? (caller(1))[3] : "main") . "] " . $text);
	}
}

=head2 error_msg()

	error_msg($message);
	$message	: a text message, scalar

Write an error message.
=cut
sub error_msg {
	my ($text) = @_;
	print("ERROR: " . $text);
}

=head2 warning_msg()

	warning_msg($message);
	$message	: a text message, scalar

Write a warning message.
=cut
sub warning_msg {
	my ($text) = @_;
	print("Warning: " . $text);
}

=head2 debug_msg()

	msg($message);
	$message	: a text message, scalar

Write a standard message.
=cut
sub msg {
	my ($text) = @_;
	print($text);
}

=head2 dump_config()

	dump_config();

Dump the current configuration.
=cut
sub dump_config {
	print Dumper $config;
}

=head2 parse_line()

	my $hash = parse_line($line);
	$line	: a line of text, scalar
	$hash	: parsed text, hash reference

Parse a line of text and return a hash reference with parsed contents.
=cut
sub parse_line {
	my ($line) = @_;
	return undef unless defined($line); 

	my @list = split(/\s+/, $line);
	if (scalar(@list) != 2) {
		warning_msg("Cannot parse line: '$line'.\n");
		return undef;
	}

	my $href = {
		'hash'		=> $list[0],
		'filename'	=> $list[1],
	};
	debug_msg("Parsed line '$line' into " . Dumper($href) . "\n");
	
	return $href;
}

=head2 move_file()

	move_file($src, $dst);
	$src	: source filename
	$dst	: destination filename

Move a file from one place to another.
=cut
sub move_file {
	my ($src, $dst) = @_;
	return undef unless (defined($src) or defined($dst));

	if (! $config->{do_it}) {
		msg("Would move: '$src' -> '$dst'\n");
	}
	else {
		msg("Moving: '$src' -> '$dst'\n");
		rename($src, $dst) or (cleanup() and die("Move failed: '$src' -> '$dst', aborting\n"));
	}
}

=head2 remove_file()

	remove_file($filename);
	$filename	: file to remove, scalar

Remove a file.
=cut
sub remove_file {
	my ($filename) = @_;
	return undef unless (defined($filename));

	if (! $config->{do_it}) {
		msg("Would remove: '$filename'\n");
	}
	else {
		msg("Removing: '$filename'\n");
		unlink($filename) or (cleanup() and die("Remove failed: '$filename', aborting\n"));
	}
}

=head2 make_link()

	make_link($target, $link_name);
	$target		: link to this file, scalar
	$link_name	: name of the symlink to create, scalar

Create a symlink to a file.
=cut
sub make_link {
	my ($target, $link_name) = @_;
	return undef unless (defined($target) and defined($link_name));

	if (! $config->{do_it}) {
		msg("Would make a symlink: '$link_name' -> '$target'\n");
	}
	else {
		msg("Making a link '$link_name' -> '$target'\n");
		symlink($target, $link_name) 
			or (cleanup() and die("Cannot make a symlink: '$link_name' -> '$target', aborting\n"));
	}
}

=head2 file_to_symlink()

	file_to_symlink($file);
	$file		: The file to convert to link, scalar.

Take a file, move it to the $config->{linkdir} directory and make a symbolic
link in the file's place.
=cut
sub file_to_symlink {
	my ($file) = @_;
	return undef unless (defined($file));

	my $new_filename = catfile($config->{linkdir}, $file->{hash});
	move_file($file->{filename}, $new_filename) or (cleanup() and die());
	
	make_link(get_target_filename($file), $file->{filename}) or (cleanup() and die());
}

=head2 no_file()

	my $file = no_file();
	$file		: A hash structure with no values filled.

Create a hash structure with no values filled in.
=cut
sub no_file {
	my $file = {
		'filename'	=> '',
		'hash'		=> '',
	};
	return $file;
}

=head2 get_target_filename()

	my $filename  = get_target_filename($file);
	$filename	: the destination filename
	$file		: A reference to a $file hash

Generate a $file's filename in the $config->{linkdir} directory. This filename
is made out of the file's hash.
=cut
sub get_target_filename {
	my ($file) = @_;
	return undef unless (defined($file));

	my $target = abs2rel(
		catfile($config->{linkdir}, $file->{hash}),
		(splitpath($file->{filename}))[1]
	);
	return $target;
}

sub help {
	print <<EOF
This script will:
    * create a directory (see --linkdir option),
    * read a properly formatted and sorted list of filehashes and filenames from
      stdin (see below),
    * for each block of equal filehashes it will:
        * create a copy of the file in the --linkdir directory
        * remove all the files in the block and replace them with equally-named
          symlinks to the newly created copy of the file

A properly sorted list of filehashes can be created like this:
    find . -type f | > file-list.txt
    cat file-list.txt | xargs -n128 md5sum >> hash-list.txt
    sort hash-list.txt > sorted-hash-list.txt

Then, feed the sorted-hash-list.txt to this program as standard input.

File options:
    -S, --basedir     : Path to the dataset.
    -L, --linkdir     : Path to the directory where we put the files we symlink 
                        to.

General operation:
    -d, --debug       : Run in debug mode.
    -y, --do-it       : Really do the stuff, not just report what would be done.
        --dump-config : Dump the current configuration.
EOF
}

# Parse the command line options.
Getopt::Long::Configure("bundling", "permute");
my $getopt = GetOptions(%$options) 
	or die "Cmdline parsing failed, stopped";

# Dump the configuration if the user so wishes.
if ($config->{dump_config}) {
	$Data::Dumper::Indent = 3;
	dump_config();
	exit;
}

# Do some initialization.
my $results = {						# Results are stored in this hash.
	'links_created'		=> 0,		# how many links have we created?
	'lines_processed'	=> 0,		# how many input lines have we processed?
};
my $link = no_file();				# This $file hash contains the file that we last linked to.
my @files;							# This list contains exactly two references to a $file hash.
chdir($config->{basedir}) or die("Could not change to: '$config->{basedir}', aborting");

# Check for the linkdir.
if (! -e $config->{linkdir}) {
	if ($config->{do_it}) {
		make_path($config->{linkdir})
			or (cleanup() and die("Could not create directory: '$config->{linkdir}'\n"));
	}
	else {
		msg("Would create directory: '$config->{linkdir}'\n");
	}
}
else {
	if (! -d $config->{linkdir} or ! -w $config->{linkdir}) {
		cleanup();
		die("'$config->{linkdir}' is not a directory or is not writable, aborting");
	}
}

# Read the filelist and do the stuff as you go along.
msg("Reading STDIN.\n");
while (1) {
	my $line = <STDIN>;

	# Check to see if we have reached end-of-file and handle the last input line properly.
	if (!defined($line)) {
		# Have we read anything up until now? This is here because you could feed this script
		# an empty file.
		if (defined($files[0])) {
			my $prev_file = $files[0];

			# We should treat the last file no different than any other file. Check to see if it is
			# unique or not.
			if ($prev_file->{hash} eq $link->{hash}) {
				# File is not unique: remove file and create a symlink if needed 
				file_to_symlink($prev_file);
				$link = $prev_file;
				$results->{links_created}++;
			}
			else {
				# File is unique: just print out the filename
				msg("Last file is unique: '$prev_file->{filename}', doing nothing.\n");
			}
		}
		msg("End-of-file encountered.\n");
		last;
	}

	# Parse the input line.
	$results->{lines_processed}++;
	debug_msg("Processing line $results->{lines_processed}.\n");
	chomp($line);
	my $file = parse_line($line);
	next if (!defined($file)); 		# go to next line if we have been unable to parse

	# Do the $file array stuff
	push(@files, $file);			# Push what've got into the list.
	next if (scalar(@files) < 2); 	# Handle the first file scenario. Make sure there are at 
									# least two elements in the list!

	# Make some handy aliases.
	my $prev_file = $files[0];
	my $this_file = $files[1];

	# Do $this_file and $prev_file have the the same hash?
	if ($prev_file->{hash} eq $this_file->{hash}) {
		debug_msg(
			"Previous file '$prev_file->{filename}' and this file '$this_file->{filename}' "
			. "have the same md5 hash: '$this_file->{hash}'\n"
		);

		# This could either be the start of a block of equal files or just the continuing of a 
		# block of euqal files. Figure it out. Have we already made the file which we link to?
		if ($link->{filename} ne '') {
			# Yes, so this is a continuing block of files. Replace the file with a symlink.
			remove_file($prev_file->{filename});
			make_link(get_target_filename($prev_file), $prev_file->{filename});
			$link = $prev_file;
			$results->{links_created}++;
		}
		else {
			# No, so this is the beginning of block of files. Create the file that we link to and
			# make a link.
			file_to_symlink($prev_file);
			$link = $prev_file;
			$results->{links_created}++;
		}
	}
	else {
		debug_msg(
			"Previous file '$prev_file->{filename}' and this file '$this_file->{filename}' " .
			"have different md5 hashes.\n"
		);

		# This is either the end of a block of equal files or all of these files really are 
		# different. Figure it out. Are the hashes of the previous file and the file we link to 
		# equal?
		if ($prev_file->{hash} eq $link->{hash}) {
			# Yes, so this is the last file of the same-file block. Just make a link.
			remove_file($prev_file->{filename});
			make_link(get_target_filename($prev_file), $prev_file->{filename});
			$link = $prev_file;
			$results->{links_created}++;
		}
		else {
			# We have a single unique file. Print out the filename of the unique file to stdout.
			msg("File is unique: '$prev_file->{filename}', doing nothing.\n");
		}

		# We are done with this link in any case, so empty it!
		$link = no_file();
	}
	# Remove the $prev_file file from the list, we don't need it anymore.
	shift(@files);
}

# Do some summary
msg("Stopped at input line: $results->{lines_processed}, links created: "
	. "$results->{links_created}\n");

# vim: set ts=4 sw=4 noet:
