#!/bin/bash

# Static webapp content pre-compression script
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

#################################################
#                   GLOBALS                     #
#################################################

RECURSIVE_OP="0"
PATTERNS="*.css *.js *.html *.htm"

#################################################
#                   FUNCTIONS                   #
#################################################

MYNAME=$(basename "$0")
VERSION="0.1"

printhelp() {
	echo -e "${TERM_BOLD}Usage:${TERM_RESET} `basename $0` [OPTIONS] FILE1 FILE2 DIR1 DIR2 ..."
	echo ""
	echo "This script compresses static content so that webserver can serve it"
	echo "directly to gzip-enabled http clients without wasting cpu time with on-the-fly"
	echo "compression."
	echo ""
	echo "WARNING: You need compressed static file aware webserver, NginX with"
	echo "         with enabled gzip_static module for example."
	echo "         See: http://wiki.nginx.org/NginxHttpGzipStaticModule"
	echo ""
	echo -e "${TERM_BOLD}OPTIONS${TERM_RESET}:"
	echo "  -r    --recurse       Recursively traverse directories and search for suitable files (Default: ${RECURSIVE_OP})"
	echo "  -c    --clear-patt    Clear current list of file glob(3) search patterns."
	echo "  -p    --pattern       Add file glob(3) pattern to list of file search patterns."
	echo ""
	echo -e "${TERM_BOLD}FILE GLOB PATTERNS${TERM_RESET}:"
	echo ""
	echo -e "    ${TERM_YELLOW}${PATTERNS}${TERM_RESET}"
	echo ""
	echo -e "${TERM_BOLD}OTHER OPTIONS${TERM_RESET}:"
	echo "  -q    --quiet         Quiet execution"
	echo "  -v    --verbose       Verbose execution"
	echo "  -V    --verison       Print out script version and exit"
	echo "  -h    --help          This little help message"
}

process_entries() {
	msg_info "Compressing static files ${TERM_YELLOW}${PATTERNS}${TERM_RESET} using gzip in ${TERM_LGREEN}${1}${TERM_RESET}"
	if [ -f "${1}" ]; then
		process_file "${1}"
	elif [ -d "${1}" ]; then
		if [ "${RECURSIVE_OP}" = "1" ]; then
			local patt=""
			local f=""
			for patt in ${PATTERNS}; do
				test -z "${patt}" && continue
				for f in `find "${1}" -type f -name "${patt}" -printf '%p\n'`; do
					process_file "${f}"
				done
			done
		else
			msg_warn "\"${1}\" is a directory, but recursive directory traversing is disabled. Skipping entry."
		fi
	fi
}

process_file() {
	local file="${1}"
	if [ ! -f "${file}" -o ! -r "${file}" ]; then
		return 1
	fi
	
	msg_info "    Processing file: ${TERM_BOLD}${file}${TERM_RESET}"
	local newfile="${file}.gz"
	
	# try to compress it...
	gzip -c9 < "${file}" > "${newfile}"
	local rv=$?
	if [ "$rv" != "0" ]; then
		msg_err "Compression of file ${file} failed."
		rm -f "${newfile}" >/dev/null 2>&1
		die
	fi
	touch --no-create -r "${file}" "${newfile}" || die "Unable to copy timestamps from file ${file} to ${newfile}."

	return 0
}

basedir_get() {
	local me=$(readlink -f "${0}")
	local dir=$(dirname "${me}")
	dir=$(dirname "${dir}")
	
	echo "${dir}"
}

#################################################
#                main program                   #
#################################################

# try to load functions
file=$(basedir_get)"/lib/interseek/sh/functions.inc.sh"
if [ ! -f "$file" ]; then
	echo "Unable to load functions file: ${file}" 1>&2
	exit 1
fi
. "$file"


# parse command line...
TEMP=`getopt -o cp:rDqvVh --long clear-patt,pattern:,recurse,quiet,verbose,debug,version,help -n "$MYNAME" -- "$@"`
eval set -- "$TEMP"
while true; do
	case $1 in
		-r|--recurse)
			RECURSIVE_OP=1
			shift
			;;
		-c|--clear-patt)
			PATTERNS=""
			shift
			;;
		-p|--pattern)
			if [ -z "${PATTERNS}" ]; then
				PATTERNS="$2"
			else
				PATTERNS="${PATTERNS} $2"
			fi
			shift 2
			;;
		-q|--quiet)
			quiet_enable
			shift
			;;
		-v|--verbose)
			verbose_enable
			shift
			;;
		-D|--debug)
			debug_enable
			shift
			;;
		-V|--version)
			printf "%s %-.2f\n" "$MYNAME" "$VERSION"
			exit 0
			;;
		-h|--help)
			printhelp
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			die "Command line parsing error: '$1'."
			;;
	esac
done

for f in $@; do
	process_entries "${f}" || die
done

exit 0
