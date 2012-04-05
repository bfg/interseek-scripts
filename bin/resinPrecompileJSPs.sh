#!/bin/bash

# Bash script interface to Resin (http://www.caucho.com) JSP pre-compiler.
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

# Resin home directory
RESIN_HOME="/export/software/resin"

# JVM flags
JAVA_FLAGS="-Xmx64M -Xdebug"

#####################################################################
#                       RUNTIME VARIABLES                           #
#####################################################################

MYNAME=$(basename "$0")
VERSION="0.20"

#####################################################################
#                           FUNCTIONS                               #
#####################################################################

basedir_get() {
	local me=$(readlink -f "${0}")
	local dir=$(dirname "${me}")
	dir=$(dirname "${dir}")
	
	echo "${dir}"
}

printhelp() {
	cat <<EOF
Usage: $MYNAME [OPTIONS] DIR1 DIR2 DIRn ...

This script uses Resin precompiler and precompiles all files in specified directory.

OPTIONS:
  -R    --resin-home=DIR   Resin install directory (Default: "${RESIN_HOME}")
  -J    --java-flags=FLAGS Java VM flags (Default: "${JAVA_FLAGS}")

  -v   --verbose           Verbose execution
  -q   --quiet             Quiet execution
  -D   --debug             Enables debugging messages
  -V    --version          Prints out script version.
  -h    --help             This help message
EOF
}

script_init() {
	local java_home=$(java_home_get)
	if [ -z "${java_home}" ]; then
		die "Unable to detect JAVA_HOME. Is java installed on this host?"
	fi
	
	# check for resin jsps...
	! ls ${RESIN_HOME}/lib/*.jar >/dev/null 2>&1 && die "Undefined or invalid RESIN_HOME directory: '${RESIN_HOME}'"
	
	# get classpath...
	CLASSPATH=$(java_classpath_get "${RESIN_HOME}")
	export CLASSPATH

	if [ ! -r "${java_home}/lib/tools.jar" ]; then
		msg_warn "File '${java_home}/lib/tools.jar' is missing. Are you shure, that you have full JAVA SDK installed?"
	else
		CLASSPATH="${CLASSPATH}:${java_home}/lib/tools.jar"
	fi

	return 0
}

resin_precompile() {
	local dir="$1"
	test -d "${dir}" -a -w "${dir}" || die "Invalid FRONTEND_DIR '${dir}': not a existing, writeable directory."
	msg_info "Precompiling JSPs in '${TERM_YELLOW}${dir}${TERM_RESET}' with Resin installed in '${TERM_LGREEN}${RESIN_HOME}${TERM_RESET}'."
	java_run_simple "com.caucho.jsp.JspCompiler" "${JAVA_FLAGS}" -app-dir "$dir" "$dir"	
	return $?
}

resin_check_precompiled_files() {
	msg_info "Checking validity of precompiled JSPs."
	local no_jsps=0
	local no_parsed_jsps=0
	local no_compiled_jsps=0

	(
		cd "$1" || die "Unable to enter frontend directory."
		
		# count files
		no_jsps=$(find . -type f -name '*.jsp' | grep -v 'WEB-INF' | wc -l)
		no_parsed_jsps=$(find WEB-INF/work/_jsp -name '*.java' | wc -l)
		no_compiled_jsps=$(find WEB-INF/work/_jsp -name '*.class' | egrep '__jsp\.class$' | wc -l)
	
		msg_info "Found ${TERM_YELLOW}${no_jsps}/${no_parsed_jsps}/${no_compiled_jsps}${TERM_RESET} (total/parsed/compiled) JSPs."
	
		# check values
		if [ "$no_jsps" -le 0 ]; then
			die "No JSPs were found in directory '$1'."
		elif [ "$no_parsed_jsps" -lt "$no_jsps" ]; then
			die "Number of parsed JSPs is lower than number of found jsps ($no_parsed_jsps/$no_jsps)."
		elif [ "$no_compiled_jsps" -lt "$no_parsed_jsps" ]; then
			die "Number of compiled JSPs is is lower than number of parsed jsps ($no_compiled_jsps/$no_parsed_jsps)."
		else
			msg_info "Number of JSPs, parsed JSPs and compiled JSPs seems to match, assuming that JSP compilation was successfull."
		fi
	) || return 1

	return 0
}

run() {
	msg_info "${MYNAME} version $VERSION startup on $(hostname) at $(date)."

	# Let's do it!
	while [ ! -z "${1}" ]; do
		local dir="${1}"
		shift
		if [ ! -d "${dir}" -o ! -r "${dir}" ]; then
			msg_warn "Not a directory: ${dir}; skipping."
			continue
		fi
		resin_precompile "${dir}" || die "Unable to precompile JSPs in '${dir}'."
		resin_check_precompiled_files "${dir}" || die "JSPs were not precompiled correctly in directory '${dir}'."
		msg_info "${TERM_LGREEN}JSPs were successfully precompiled${TERM_RESET} in directory '${TERM_YELLOW}${dir}${TERM_RESET}'."
	done

	msg_info "${TERM_LGREEN}Successfully compiled JSPs in all specified directories.${TERM_RESET}"
	return 0	
}

#####################################################################
#                             MAIN                                  #
#####################################################################

# try to load functions
file=$(basedir_get)"/lib/interseek/sh/functions.inc.sh"
if [ ! -f "$file" ]; then
	echo "Unable to load functions file: ${file}" 1>&2
	exit 1
fi
. "$file"

# parse command line...
TEMP=$(getopt -o R:J:DqvVh --long resin-home:,java-flags:,quiet,verbose,debug,version,help -n "$MYNAME" -- "$@")
test "$?" != "0" && die "Command line parsing error."  
eval set -- "$TEMP"
while true; do
	case $1 in
		-R|--resin-home)
			RESIN_HOME="${2}"
			shift 2
			;;
		-J|--java-flags)
			JAVA_FLAGS="${2}"
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
			printf "%s %-.2f\n" "${MYNAME}" "${VERSION}"
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

# load additional plugins...
plugin_load "java"

script_init

run "$@" || die

# EOF
