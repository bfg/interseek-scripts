#!/bin/bash

# Library of reusable bash functions.
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

#####################################################################
#                      GLOBAL SHELL VARIABLES                       #
#####################################################################

# last error message
__ERROR=""

# DEBUG? (1 on, 0 off)
__DEBUG="0"

# VERBOSE? (1 on, 0 off)
__VERBOSE="0"

# plugin base directory...
__BASEDIR=""

# already loaded and initialized?
__INITIALIZED="0"

# should msg_* function prepent current time string?
__MSG_TIME="0"

#####################################################################
#                       BASIC SHELL FUNCTIONS                       #
#####################################################################

# retuns functions library version number
functions_version() {
	echo "0.11"
}

# Prints last error message
#
# ARGUMENTS:
#	
# RETURNS: always 0
error_get() {
	echo "${__ERROR}"
	return 0
}

# Sets last error message
#
# ARGUMENTS:
#	$1 (string, "") :: Error message
#
# RETURNS: always 0
error_set() {
	__ERROR="${1}"
	return 0
}

# Enables debugging messages
debug_enable() {
	__DEBUG=1
	verbose_enable
}

# Disables debugging messages
debug_disable() {
	__DEBUG=0
	verbose_disable
}

# Prints debugging message status
debug_status() {
	test "$1" != "0" && echo "${__DEBUG}"
	test "${__DEBUG}" = "1"
}

# Enables verbose messages
verbose_enable() {
	__VERBOSE=1
	__QUIET=0
}

# Disables verbose messages
verbose_disable() {
	__VERBOSE=0
}

# Prints verbose message status
verbose_status() {
	test "$1" != "0" && echo "${__VERBOSE}"
	test "${__VERBOSE}" = "1"
}

# Enables quiet execution mode (disables printing of non-error messages)
quiet_enable() {
	__QUIET=1
	__VERBOSE=0
}

# Disables quiet execution
quiet_disable() {
	__QUIET=0
}

# Prints quiet execution status...
quiet_status() {
	test "$1" != "0" && echo "${__QUIET}"
	test "${__QUIET}" = "1"
}

# Enables timestamps in msg_* functions
msg_func_ts_enable() {
	__MSG_TIME="1"
}

# Disables timestamps in msg_* functions
msg_func_ts_disable() {
	__MSG_TIME="0"
}

# Prints msg_* functions timestamp printing status...
msg_func_ts_status() {
	test "$1" != "0" && echo "${__MSG_TIME}"
	test "${__MSG_TIME}" = "1"
}

# Writes error message and exits with error code 1
#
# ARGUMENTS:
#	one or more strings
#
# RETURNS:
#	never
die() {
	msg_err "$@"
	exit 1
}

# writes informational message on stdout
# ARGUMENTS:
#	one or more strings
#
# RETURNS:
#	always 0
msg_info() {
	if [ "${__QUIET}" != "1" ]; then
		local str=""
		local ts=""
		test "${__MSG_TIME}" = "1" && ts=$(date +"[%Y/%m/%d %H:%M:%S] ")

		if [ "${__DEBUG}" = "1" ]; then
			str="[${TERM_DGRAY}${FUNCNAME[1]}()${TERM_RESET}, # ${TERM_DGRAY}${BASH_LINENO}${TERM_RESET}]"
		fi
		if [ -z "${str}" ]; then
			str="$@"
		else
			str="${str} $@"
		fi
		echo -e "${ts}${TERM_BOLD}INFO   :${TERM_RESET} ${str}${TERM_RESET}"
	fi
	return 0
}

# Writes verbose message to stdout if verbosity is enabled
#
# ARGUMENTS:
# 	one or more strings
#
# RETURNS: always 0
msg_verbose() {
	if [ "${__VERBOSE}" = "1" ]; then
		local str=""
		local ts=""
		test "${__MSG_TIME}" = "1" && ts=$(date +"[%Y/%m/%d %H:%M:%S] ")

		if [ "${__DEBUG}" = "1" ]; then
			str=" [${TERM_DGRAY}${FUNCNAME[1]}()${TERM_RESET}, # ${TERM_DGRAY}${BASH_LINENO}${TERM_RESET}]"
		fi
		echo -e "${ts}${TERM_BLUE}VERBOSE:${TERM_RESET}${str} $@ ${TERM_RESET}" 1>&2
	fi
	return 0
}

# Writes debugging message to stderr if debuggin is enabled
#
# ARGUMENTS:
#	one or more strings
# 
# RETURNS: always returns 0 
msg_debug() {
	if [ "${__DEBUG}" = "1" ]; then
		local ts=""
		test "${__MSG_TIME}" = "1" && ts=$(date +"[%Y/%m/%d %H:%M:%S] ")

		echo -e "${ts}${TERM_DGRAY}DEBUG  :${TERM_RESET} [${TERM_DGRAY}${FUNCNAME[1]}()${TERM_RESET}, # ${TERM_DGRAY}${BASH_LINENO}${TERM_RESET}] $@ ${TERM_RESET}" 1>&2
	fi 
	return 0
}

# writes warning message on stdout
#
# ARGUMENTS:
#	one or more strings
#
# RETURNS:
#	always 0
msg_warn() {
	local str=""
	local ts=""
	test "${__MSG_TIME}" = "1" && ts=$(date +"[%Y/%m/%d %H:%M:%S] ")

	if [ "${__DEBUG}" = "1" ]; then
		str=" [${TERM_DGRAY}${FUNCNAME[1]}()${TERM_RESET}, # ${TERM_DGRAY}${BASH_LINENO}${TERM_RESET}]"
	fi
	echo -e "${ts}${TERM_YELLOW}WARNING:${TERM_RESET}${str} $@ ${TERM_RESET}"
	return 0
}

msg_err() {
	local err="$@"
	test -z "${err}" && err="${__ERROR}"

	local str=""
	local ts=""
	test "${__MSG_TIME}" = "1" && ts=$(date +"[%Y/%m/%d %H:%M:%S] ")
	if [ "${__DEBUG}" = "1" ]; then
		str=" [${TERM_DGRAY}${FUNCNAME[1]}()${TERM_RESET}, # ${TERM_DGRAY}${BASH_LINENO}${TERM_RESET}]"
	fi

	echo -e "${ts}${TERM_LRED}ERROR  :${TERM_RESET}${str} ${err} ${TERM_RESET}"
	return 0
}

msg_error() {
	msg_err "$@"
}

msg_fatal() {
	die "$@"
}

msg_print() {
	if [ "${__QUIET}" != "1" ]; then
		echo "$@"
	fi
	return 0
}

msg_action_info() {
	msg_info ""
	msg_info "$@"
	msg_info ""
	msg_print ""
}

# initializes shell color ${TERM_*} environment variables
#
# ARGUMENTS:
#
# RETURNS:
#	always 0
tty_colors_init() {
	# stdout and stderr *must* be
	# tty in order to install real shell
	# color codes...
	if [ -t 1 -a -t 2 ]; then
		TERM_WHITE="\033[1;37m"
		TERM_YELLOW="\033[1;33m"
		TERM_LPURPLE="\033[1;35m"
		TERM_LRED="\033[1;31m"
		TERM_LCYAN="\033[1;36m"
		TERM_LGREEN="\033[1;32m"
		TERM_LBLUE="\033[1;34m"
		TERM_DGRAY="\033[1;30m"
		TERM_GRAY="\033[0;37m"
		TERM_BROWN="\033[0;33m"
		TERM_PURPLE="\033[0;35m"
		TERM_RED="\033[0;31m"
		TERM_CYAN="\033[0;36m"
		TERM_GREEN="\033[0;32m"
		TERM_BLUE="\033[0;34m"
		TERM_BLACK="\033[0;30m"
		TERM_BOLD="\033[40m\033[1;37m"
		TERM_RESET="\033[0m"
	else
		TERM_WHITE=""
		TERM_YELLOW=""
		TERM_LPURPLE=""
		TERM_LRED=""
		TERM_LCYAN=""
		TERM_LGREEN=""
		TERM_LBLUE=""
		TERM_DGRAY=""
		TERM_GRAY=""
		TERM_BROWN=""
		TERM_PURPLE=""
		TERM_RED=""
		TERM_CYAN=""
		TERM_GREEN=""
		TERM_BLUE=""
		TERM_BLACK=""
		TERM_BOLD=""
		TERM_RESET=""
	fi
	return 0
}

# Loads shell configuration from file or URL address
#
# ARGUMENTS:
#	$1 (string, "") :: Configuration filename or url address
#	$2 (string, "") :: HTTP/FTP username
#	$3 (string, "") :: HTTP/FTP password
#
# RETURNS:
#	0 on success, otherwise 1.
config_load() {
	local file="${1}"
	local user="${2}"
	local pass="${3}"
	if [ -z "${file}" ]; then
		error_set "Undefined configuration file."
		return 1
	fi

	# compute possible configuration directory...
	local possible_config_dir="${HOME}/config/$(basename $0 .sh)"

	if [ ! -f "${file}" -o ! -r "${file}" ]; then
		# check if file exists in possible configuration dir
		local f="${possible_config_dir}/${file}"
		msg_debug "Checking for configuration file ${file} in directory: ${possible_config_dir}"
		if [ -f "${f}" -a -r "${f}" ]; then
			msg_debug "Configuration file ${file} found in directory ${possible_config_dir}, trying to load ${f}"
			__config_load_file "${f}"
			return $?
		fi

		# if it's URL, parse it
		if echo "$file" | egrep -qi '^(http|https|ftp)://'; then
			__config_load_www "${file}" "${user}" "${pass}"
			return $?
		else
			error_set "Invalid configuration file: '${file}'"
			return 1
		fi
	else
		__config_load_file "${file}"
		return $?
	fi

	return 0
}

__config_load_file() {
	local file="${1}"
	if [ -z "${file}" -o ! -f "${file}" -o ! -r "${file}" ]; then
		error_set "Invalid or unreadable configuration file: '${file}'"
		return 1
	fi
	
	# try to load it...
	msg_debug "Trying to load configuration file '${file}'."
	. "${file}"
	local rv=$?

	if [ "${rv}" != "0" ]; then
		error_set "Error parsing configuration file '${file}': Exit status: ${rv}"
		return 1
	fi
	
	msg_info "Loaded configuration file '${TERM_LGREEN}${file}${TERM_RESET}'."
	return 0
}

__config_load_www() {
	local url="$1"
	local user="$2"
	local pass="$3"
	
	# read password from command prompt if necessary...
	if [ ! -z "${user}" -a -z "${pass}" ]; then
		config_load_read_pw
		if [ -z "${WWW_PASSWORD}" ]; then
			msg_warn "Using empty password for username ${TERM_BOLD}${user}${TERM_RESET} for URL ${TERM_BOLD}${url}${TERM_RESET}."
		fi
	fi
	
	# create temporary output file...
	local tmpf=$(mktemp)
	if [ ! -w "${tmpf}" ]; then
		die "Unable to create tmp file for WWW/SVN configuration file.";
	fi
	
	# try to download configuration
	local opt="--no-check-certificate"
	test ! -z "${user}" && opt="${opt} --user ${user}"
	test ! -z "${pass}" && opt="${opt} --password ${pass}"

	if ! wget ${opt} -q -O "${tmpf}" "${url}"; then
		die "Unable to load $MYNAME configuration from ${url}"
	fi

	# load configuration
	if ! __config_load_file "${tmpf}"; then
		rm -f "${tmpf}" >/dev/null 2>&1
		return 1
	fi

	# we succeeded!
	rm -f "${tmpf}" >/dev/null 2>&1

	return 0
}

# Prints default script configuration to stdout
#
# ARGUMENTS:
#
# RETURNS:
# 	always 0
config_default_print() {
	local start_line="$1"
	local stop_line="$2"
	local lines=$((stop_line - start_line + 1))
	local script="$0"

	if [ ! -x "$script" ]; then
		script=$(which "$script")
		test ! -x "$script" && die "Unable to find '$script' in \$PATH."
	fi

	head -n "${stop_line}" < $script | tail -n $lines | sed -e 's/^[A-Z]/# \0/g' | sed -e 's/^# die/die/'

	return 0
}

# prints base directory of specified binary
__basedir_get() {
	if [ -z "${__BASEDIR}" ]; then
		__BASEDIR=$(dirname "${BASH_SOURCE[0]}")
	fi

	echo "${__BASEDIR}"
}

# Loads script plugin and initializes it.
#
# ARGUMENTS:
#	$1 (string, "") :: Plugin name (without ".inc.sh" file suffix)
#	$2 (boolean, 0) :: 
#
# RETURNS: 0 on success, otherwise 1
plugin_load() {
	local name="${1}"
	local fatal="${2}"
	test -z "${fatal}" && fatal="0"

	# compute source filename
	local file=$(__basedir_get)
	file="${file}/${name}.inc.sh"
	msg_debug "Computed plugin file: $file"
	
	# check if this plugin is already loaded
	local var_name="__PLUGIN_LOADED_${name}"
	
	local rv=0
	
	if [ -f "${file}" -a -r "${file}" ]; then
		msg_debug "Loading plugin file: ${file}"
		. "${file}"
		rv=$?

		# check for injuries...
		if [ "$rv" != "0" ]; then
			error_set "Plugin ${name} (file: ${file}) returned non-zero execution status: $?"
			test "${fatal}" = "1" && die
			return 1
		fi
		msg_debug "File successfully loaded."

		# check for plugin initialization function...
		local func_name="${name}_init"
		declare -F "${func_name}" >/dev/null 2>&1
		rv=$?
		if [ "$rv" != "0" ]; then
			msg_warn "Plugin ${name} doesn't implement plugin initialization function ${func_name}()."
		else
			msg_debug "Running plugin initialization function ${func_name}()."
			${func_name}
			rv=$?

			# check for injuries
			if [ "$rv" != "0" ]; then
				error_set "Plugin initialization function ${func_name}() exited with non-zero status $rv."
				test "${fatal}" = "1" && die
				return 1
			fi
		fi
		
		# check for plugin version function...
		func_name="${name}_version"
		declare -F "${func_name}" >/dev/null 2>&1
		rv=$?
		if [ "$rv" = "0" ]; then
			local v=$(${func_name} | head -n 1)
			msg_verbose "Successfully loaded plugin name ${name} version ${v}."
		else
			msg_warn "Plugin ${name} doesn't implement function ${func_name}."
		fi
	else
		error_set "Invalid or non-existing plugin: ${name}"
		test "${fatal}" = "1" && die
		return 1
	fi

	# mark this plugin as loaded
	eval "${var_name}=1"

	return 0
}

# Lists all available plugins
# 
# ARGUMENTS:
#
# RETURNS: always 0
plugin_list() {
	local dir=$(__basedir_get)
	local f=""
	for f in $(ls ${dir}/*.inc.sh); do
		local f=$(basename "${f}")
		echo "${f}" | sed -e 's/\.inc\.sh//g' | grep -vi "functions" | grep -vi "example"
	done
}

# Parses a=b,c=d,x=y strings and extracts and prints named key value
#
# ARGUMENTS:
#	$1 (string, "")	:: String containing flags
#	$2 (string, "") :: Named key name
#
# RETURNS: always 0
parse_flags() {
	echo "${1}" | tr '[,;]' '\n' | sed 's/\ *=\ */=/' | sed -e 's/^\ *//g' | egrep "^${2}=" | awk -F= '{print $2}'
	return 0
}

# Prints string representation of any shell variable to stdout
#
# ARGUMENTS:
#	$1	(string, "") :: variable name
#
# RETURNS: always 0
var_as_str() {
	local var_name="${1}"
	if [ -z "${var_name}" ]; then
		echo ""
		return 0
	fi
	set | egrep "^${var_name}=" |sed -e "s/^${var_name}=\(.*\)/\1/g"
	return 0
}

# Runs series of commands specified in string/array variable
#
# EXAMPLE:
#
# # define hook variable as array (if you want to execute multiple
# # commands in a single hook execution) or as a simple string
# # if you want to execute only one command during hook execution
# SOME_WEIRD_HOOK=(
# 	'ls /etc'
#	'cat /etc/passwd'
#	'touch /tmp/test'
# 	'/bin/false'
# )
# 
# # execute hook
# hook_run "SOME_WEIRD_HOOK"
#
# # execute hook that triggers fatal exception
# # if any of hook commands fail
# hook_run "SOME_WEIRD_HOOK" 1
#
# ARGUMENTS:
#	$1 (string, "")	:: variable named containing hook command(s)
#	$2 (boolean, 0)	:: If any of commands in a hook fails, trigger fatal exception
#
# RETURNS: 0 on success, otherwise number of failed hook commands
hook_run() {
	test -z "$1" && die "Unspecified hook name."
	local hook_name="$1"
	local fatal="$2"
	test -z "${fatal}" && fatal="0"
	local failed=0

	local hook_value
	declare -a hook_value=$(var_as_str "${hook_name}")

	msg_info "Running hook: '${TERM_PURPLE}${hook_name}${TERM_RESET}'."
	if [ -z "${hook_value}" ]; then
		msg_verbose "Empty hook '${TERM_BOLD}${hook_name}${TERM_RESET}', ignoring, returning success."
		return 0
	fi

	# let's execute hook (array or strings)
	local j=0
	while [ -n "${hook_value[${j}]}" ]; do
		local eval_str=$(shell_pattern_resolve "${hook_value[${j}]}")
		j=$(($j + 1))
		# there is no way to figure out if eval string was "compiled" successfully
		# well, i'm not sure :)
		msg_info "    Running hook ${TERM_LPURPLE}${hook_name}[${j}]${TERM_RESET}: ${TERM_DGRAY}${eval_str}${TERM_RESET}"

		# execute the hook name
		eval "${eval_str}"
		local rv=$?
		if [ "${rv}" != "0" ]; then
			error_set "Error running hook ${hook_name}[${j}]."
			test "${fatal}" = "1" && die
			return 1 
			failed=$((failed + 1))
		fi
	done

	return ${failed}
}

# Resolves all shell variables and strftime(3) placeholders in
# specified string and prints resolved string to stdout
#
# ARGUMENTS:
#	$1 (string, "") :: pattern
#	$2 (string, <current_time>) :: date(1) pattern
#
# RETURNS: 0
shell_pattern_resolve() {
	local pattern="${1}"
	local date="${2}"

	# backup LC_* variables
	local _lc_all="${LC_ALL}"
	local _lc_time="${LC_TIME}"
	unset LC_ALL LC_TIME

	msg_debug "Original pattern: ${pattern}"
	if [ -z "${date}" ]; then
		date=$(date)
		msg_debug "Empty provided date pattern, using current time: ${date}"
	fi
	
	pattern=`eval "echo \${pattern}"`
	msg_debug "Shell resolved pattern: ${pattern}"

	# resolve strftime(3) patterns...
	pattern=$(date +"${pattern}" --date="${date}")
	msg_debug "strftime(3) resolved pattern: ${pattern}"
	
	# restore LC_* variables...
	if [ ! -z "${_lc_all}" ]; then
		export LC_ALL="${_lc_all}"
	fi
	if [ ! -z "${_lc_time}" ]; then
		export LC_TIME="${_lc_time}"
	fi
	
	# print pattern
	echo "${pattern}"
	return 0
}

# Reads password from console prompt
#
# ARGUMENTS:
#	$1 (string, "")	:: Variable name into which password will be copied
#	$2 (string, "")	:: specifies username
#
# RETURNS: 0
password_read() {
	local var_name="${1}"
	test -z "${var_name}" && die "Usage: password_read VARIABLE_NAME [USERNAME]"

	local user="${2}"
	local str=""
	if [ ! -z "${user}" ]; then
		str=" for user ${user}"
	fi

	local s=""
	echo -en "${TERM_BOLD}Enter password${str}${TERM_RESET}:"
	stty -echo
	read s
	stty echo
	echo ""

	# set requested variable
	eval "${var_name}='${s}'"

	return 0
}

# Creates file's parent directory if it doesn't exits yet
#
# ARGUMENTS:
#	$1 (string, "") :: filename
#
# RETURNS: 0 on success, otherwise 1
file_parent_create() {
	local file="${1}"
	if [ -z "${file}" ]; then
		error_set "Invalid filename."
		return 1
	fi
	local parent=$(dirname "${file}")
	msg_debug "Checking file '${file}' parent directory: '${parent}'"
	
	if [ ! -e "${parent}" ]; then
		# try to create it
		msg_verbose "Trying to create parent directory: '${parent}'"
		if ! mkdir -p "${parent}" >/dev/null 2>&1; then
			error_set "Unable to create parent directory: ${parent}"
			return 1
		fi
	else
		if [ ! -d "${parent}" ]; then
			error_set "Filesystem object '${parent}' exists, but is not a directory."
			return 1
		fi
	fi
	msg_debug "Parent directory '${parent}' is ok."

	return 0	
}

# Asks user for input
#
# ARGUMENTS:
#   $1 (string, ""): Question (required)
#   $2 (string, ""): Default answer (optional)
#
#
# NOTE: answer can be obtained by issuing
#       "question_answer" function
#
# RETURNS: 0 on success, otherwise 1
__ANSWER=""
question() {
	local question="${1}"
	local default="${2}"
	test -z "${question}" && {
		error_set "No question."
		return 1
	}

	# clear last answer
	ANSWER=""
	local ans=""
	local q="${question}"
	test ! -z "${default}" && q="${q} [${default}]"
	q="${q}: "

	while true; do
		echo -en "${q}"
		read ans
		if [ -z "${ans}" -a ! -z "${default}" ]; then
			ans="${default}"
			break
		elif [ ! -z "${ans}" ]; then
			break
		fi
	done

	__ANSWER="${ans}"
	return 0
}

# Prints last user input to question function
#
# ARGUMENTS:
#
# RETURNS: always 0
question_answer() {
	echo "${__ANSWER}"
	return 0
}

# Asks user for true/false input
#
# ARGUMENTS:
#	$1 (string, "Are you sure?") :: Question
#   $2 (string, "n") :: Default answer ("y" or "n")
#
# RETURNS: 0 on success (answer == y), otherwise 1
question_tf() {
	local question="${1}"
	local default="${2}"
	test -z "${question}" && question="Are you sure?"
	test -z "${default}" && default="n"

	# compute question
	q="${question}"
	case ${default} in
		1|[Yy]|[Yy][Ee][Ss]|[Tt]|[Tt][Rr][Uu][Ee])
			q="${q} [Y/n]: "
			;;
		*)
			q="${q} [y/N]: "
			;;
	esac

	local ans=""
	echo -en "${q}"
	read ans

	test -z "$ans" && ans="${default}"

	local retv=1

	case $ans in
		1|[Yy]|[Yy][Ee][Ss]|[Tt]|[Tt][Rr][Uu][Ee])
			retv=0
			;;
		*)
			retv=1
			;;
	esac

	return ${retv}
}

# Creates a temporary file
#
# ARGUMENTS:
#   $1 (string) :: temporary file basename
#
# RETURNS: 0 on success, otherwise something else
tempfile_create() {
	local bname="${1:-tmpfile}"
	mktemp -t "${bname}.XXXXXXX"
}

# Removes a temporary file
#
# ARGUMENTS:
#   $1 (string) :: filename
#
# RETURNS: 0 on success (answer == y), otherwise 1
tempfile_remove() {
	local file="$1"
	[ -z "$file" ] && {
		msg_debug "Cannot remove tempfile: no file given."
		return 1
	}
	rm -f "$file" > /dev/null 2>&1
	local retval=$?
	[ $retval -gt 0 ] && {
		msg_debug "Error while removing tempfile '$file'"
	}
	return $retval
}

#####################################################################
#              BASIC SHELL FUNCTIONS REQUIRED MODULES               #
#####################################################################

# initialize base functions if necessary
if [ "${__INITIALIZED}" = "0" ]; then
	# initialize colours...
	tty_colors_init

	# compute our own base directory
	__basedir_get >/dev/null 2>&1

	# mark it as initialized
	__INITIALIZED="1"
fi

# EOF
