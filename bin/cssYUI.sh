#!/bin/bash

# Shell interface to Yahoo YUI CSS compressor.
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

RECURSIVE_OP=0
EXTENSION="css"
FAKE_IT=0
CHARSET="UTF-8"
TMP_DIR="/tmp"

#################################################
#                   FUNCTIONS                   #
#################################################

JAVA_CLASS="com.yahoo.platform.yui.compressor.YUICompressor"
MYNAME=$(basename "$0")
VERSION="0.21"

printhelp() {
	echo -e "${TERM_BOLD}Usage:${TERM_RESET} `basename $0` [OPTIONS] FILE1 FILE2 DIR1 DIR2 ..."
	echo ""
	echo "This script uses Java program YUICompressor written by Yahoo Inc to reduce"
	echo "size of CSS files located under FILEx or"
	echo "DIRx filesystem locations."
	echo ""
	echo -e "${TERM_BOLD}OPTIONS${TERM_RESET}:"
	echo "  -r    --recurse        Recursively traverse directories and search for"
	echo "                         suitable files (Default: ${RECURSIVE_OP})"
	echo "  -C    --charset        Use specified file charset (Default: \"${CHARSET}\")"
	echo "  -E    --extension      Search for files with specified extension (Default: \"${EXTENSION}\")"
	echo "  -T    --tmp-dir        Directory for temporaty files (Default: \"${TMP_DIR}\")"
	echo ""
	echo -e "${TERM_BOLD}OTHER OPTIONS${TERM_RESET}:"
	echo "  -q    --quiet          Quiet execution"
	echo "  -v    --verbose        Verbose execution"
	echo "  -D    --debug          Enable debugging messages."
	echo "  -n    --fake-it        Fake execution (Default: ${FAKE_IT})"
	echo "  -V    --version        Print out script version and exit"
	echo "  -h    --help           This little help message"
}

process_entries() {
	msg_info "Minifying ${TERM_YELLOW}CSS${TERM_RESET} files in ${TERM_LGREEN}${1}${TERM_RESET}"
	if [ -f "${1}" ]; then
		process_file "${1}"
	elif [ -d "${1}" ]; then
		if [ "${RECURSIVE_OP}" = "1" ]; then
			for f in `find "${1}" -type f -name "*.${EXTENSION}" -printf '%p\n'`; do
				process_file "${f}" || return 1
			done
		else
			msg_warn "\"${1}\" is a directory, but recursive directory traversing is disabled. Skipping entry."
		fi
	fi
}

process_file() {
	local fname="${1}"
	local fname_len=${#fname}
	extension_len=${#EXTENSION}
	local pos=$(($fname_len - $extension_len))
	local extension=${fname:$pos}

	if [ "${extension}" != "${EXTENSION}" ]; then
		msg_warn "File \"${fname}\" doesn't have extension \"${EXTENSION}\" [${extension}], skipping operation."
		return 0
	fi

	msg_info "Processing file: ${TERM_BOLD}${fname}${TERM_RESET}"
	if [ "$FAKE_IT" != "1" ]; then
		local tmp_fname=$(mktemp -q "${TMP_DIR}/${MYNAME}.XXXXXX")
		if [ -z "${tmp_fname}" ]; then
			error_set "Unable to create temporary file."
			return 1
		fi
		msg_debug "Created temporary file: ${tmp_fname}"

		local opts=""
		test ! -z "${CHARSET}" && opts="${opts} --charset ${CHARSET}"
		verbose_status >/dev/null 2>&1 && opts="${opts} -v"

		# run java runtime
		if ! java_run_simple "${JAVA_CLASS}" "" ${opts} --type css "${fname}" -o "${tmp_fname}"; then
			return 1
		fi

		# overwrite original filename
		msg_verbose "Overwriting ${fname} with ${tmp_fname}"
		if ! cp -f "${tmp_fname}" "${fname}" && rm -f "${tmp_fname}"; then
			rm -f "${tmp_fname}" >/dev/null 2>&1
			error_set "Unable to owerwrite original file."
			return 1
		fi
		rm -f "${tmp_fname}" >/dev/null 2>&1
	fi
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
TEMP=`getopt -o rE:C:T:DqvnVh --long recurse,extension:,charset:,tmp-dir:,quiet,verbose,debug,version,help -n "$MYNAME" -- "$@"`
eval set -- "$TEMP"
while true; do
	case $1 in
		-r|--recurse)
			RECURSIVE_OP=1
			shift
			;;
		-E|--extension)
			EXTENSION="$2"
			shift 2
			;;
		-C|--charset)
			CHARSET="${2}"
			shift 2
			;;
		-T|--tmp-dir)
			TMP_DIR="$2"
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

plugin_load "java" 1

# set CLASSPATH directory...
JAVA_LIBDIR=$(basedir_get)/lib/interseek/java
CLASSPATH=$(java_classpath_get "${JAVA_LIBDIR}")
export CLASSPATH

if [ -z "${CLASSPATH}" ]; then
	die "Empty classpath; Do you have any JAR files in ${JAVA_LIBDIR}?"
fi

for f in $@; do
	process_entries "${f}" || die
done

exit 0
# EOF
