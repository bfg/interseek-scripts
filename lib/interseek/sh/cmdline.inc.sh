#!/bin/bash

# This bash library maps command-line arguments to global variables.
#
# Copyright (C) 2010 Uroš Golja
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
#                      GLOBAL PLUGIN VARIABLES                      #
#####################################################################
ARG_UNPARSED=""
_CMDLINE_VERSION="trunk"

#####################################################################
#                 BUILT-IN COMMAND-LINE ARGUMENTS                   #
#####################################################################
ARG_DEBUG="d"
ARGL_DEBUG="debug"
CONF_DEBUG=""
HELP_DEBUG="Enable debug mode."

ARG_VERBOSE="v"
ARGL_VERBOSE="verbose"
CONF_VERBOSE=""
HELP_VERBOSE="Enable verbose mode."

ARG_CONFFILE="f:"
ARGL_CONFFILE="config-file:"
CONF_CONFFILE=""
HELP_CONFFILE="filename\tPath to configuration file."
VAL_CONFFILE=1

ARG_PRINT_ARGS="0"
ARGL_PRINT_ARGS="args"
CONF_PRINT_ARGS=""
HELP_PRINT_ARGS="Print all available command-line switches in no particular order."

ARG_PRINT_CONFIG="c"
ARGL_PRINT_CONFIG="config"
CONF_PRINT_CONFIG=""
HELP_PRINT_CONFIG="Print current configuration."

ARG_PRINT_CONFIG_AFTER_VALIDATE="C"
ARGL_PRINT_CONFIG_AFTER_VALIDATE="config-after-validate"
CONF_PRINT_CONFIG_AFTER_VALIDATE=""
HELP_PRINT_CONFIG_AFTER_VALIDATE="Print current configuration after the validation has completed."

ARG_PRINT_HELP="h"
ARGL_PRINT_HELP="help"
CONF_PRINT_HELP=""
HELP_PRINT_HELP="Print this help."

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################
cmdline_version() {
	echo $_CMDLINE_VERSION
}

cmdline_init() {
	# parse options
	cmdline_parse $_CMDLINE_ARGS || {
		msg_error "$? Error(s) encountered while parsing options, aborting."
		return 1
	}

	# set debug
	[ -n "$CONF_DEBUG" ] && {
		debug_enable
		msg_debug "Enabling debug mode."
	}

	# set verbose
	[ -n "$CONF_VERBOSE" ] && {
		verbose_enable
		msg_debug "Enabling verbose mode."
	}

	# print help if so inclined
	[ -n "$CONF_PRINT_HELP" ] && {
		msg_help
		cmdline_help
		exit
	}

	# validate configuration
	cmdline_validate || return 1
	return 0
}

cmdline_validate() {
	msg_debug "Validating configuration..."
	cmdline_validate || {
		msg_error "$? Error(s) encountered while validating configuration options, aborting."
		exit
	}
	return 0
}

#####################################################################
#                      BUILT-IN VALIDATOR FUNCTIONS                 #
#####################################################################
# validator functions return 0 on success, and 1 or greater on error.
validate_CONFFILE() {
	if [ -n "$CONF_CONFFILE" ] ; then 
		if [ ! -r "$CONF_CONFFILE" ] ; then
			msg_error "Configuration file \"$CONF_CONFFILE\" is not readable."
			return 1
		else
			return 0
		fi
	else
		return 0
	fi
}

#####################################################################
#                            STUFF                                  #
#####################################################################
cmdline_helpfor() {
	local optname=$1
	[ -z "$optname" ] && return 1
	
	local fs_short="    %-3.3s                 "
	local fs_long="    %-20.20s"
	local fs_both="    %-2.2s, %-20.20s"
	
	local arg_varname="ARG_${optname}"
	local argl_varname="ARGL_${optname}"
	local help_varname="HELP_${optname}"
	
	# only long arg
	if [ -z "${!arg_varname}" -a -n "${!argl_varname}" ] ; then
		printf "    $fs_long" "--${!argl_varname}"
		echo -e ${!help_varname}
	# only short arg
	elif [ -n "${!arg_varname}" -a -z "${!argl_varname}" ] ; then
		printf "    $fs_short" "-${!arg_varname}"
		echo -e ${!help_varname}
	# both args
	elif [ -n "${!arg_varname}" -a -n "${!argl_varname}" ] ; then
		printf "$fs_both" "-${!arg_varname}" "--${!argl_varname}"
		echo -e ${!help_varname}
	fi

	return 0
}

cmdline_help() {
	echo -e "  General cmdline.inc.sh options:"
	cmdline_helpfor PRINT_ARGS
	cmdline_helpfor PRINT_HELP
	cmdline_helpfor PRINT_CONFIG
	cmdline_helpfor DRYRUN
	cmdline_helpfor CONFFILE
	cmdline_helpfor VERBOSE
	cmdline_helpfor DEBUG
}

# Print command-line options and switches
cmdline_msg_args() {
	local argname optname formatstring

	echo "Valid short command-line arguments are:"
	formatstring="%-8.8s %-35.35s %-35.35s" 
	printf "${formatstring}DESCRIPTION\n" "ARGUMENT" "ARGUMENT_VARIABLE" "CONF_VARIABLE"
	# cycle through all short options
	for argname in ${!ARG_*} ; do
		optname="CONF_${argname#ARG_}"
		help_varname="HELP_${argname#ARG_}"
		printf "$formatstring" "-${!argname}" "${argname}" "${optname}" 
		echo -e ${!help_varname}
	done

	echo -e "\nValid long command-line arguments are:"
	formatstring="%-20.20s %-35.35s %-35.35s" 
	printf "${formatstring}DESCRIPTION\n" "ARGUMENT" "ARGUMENT_VARIABLE" "CONF_VARIABLE"
	# cycle through all long options
	for argname in ${!ARGL_*} ; do
		optname="CONF_${argname#ARGL_}"
		help_varname="HELP_${argname#ARGL_}"
		printf "$formatstring" "--${!argname}" "${argname}" "${optname}" 
		echo -e ${!help_varname}
	done
}

cmdline_parse() {
	msg_debug "cmdline_parse start"

	# construct short option string
	local argname optstring_short
	for argname in ${!ARG_*} ; do
		optstring_short="${optstring_short}${!argname}"
	done
	msg_debug "\tShort optionstring (getopt): \"$optstring_short\""

	# construct long option string
	local optstring_long
	for argname in ${!ARGL_*} ; do
		# need to do some fancy expansion to glue that comma (',') to the end of each option
		optstring_long="${optstring_long:+${optstring_long},}${!argname}"
	done
	msg_debug "\tLong optionstring (getopt): \"$optstring_long\""

	# fire up getopt
	local getopt_output
	getopt_output=$(getopt -o "$optstring_short" --long "$optstring_long" -- "$@") || {
		exit 1
	}
	eval set -- "$getopt_output"

	# search for options
	local optname optvalue optfound
	while true ; do
		msg_debug "\tArglist: \"$@\"."

		# exit if we are at the end of parsable options
		[ "$1" == "--" ] && {
			shift

			# check to see if we where called just to print out the arguments
			[ -n "$CONF_PRINT_ARGS" ] && {
				cmdline_msg_args
				exit 0
			}

			# print the config and exit if we were instructed to do so
			[ -n "$CONF_PRINT_CONFIG" ] && {
				cmdline_msg_conf
				exit 0
			}

			# exit, fill up the ARG_UNPARSED
			msg_debug "cmdline_parse stop"
			ARG_UNPARSED="$@"
			return 0
		}

		# cycle through all short command-line options, search for a match
		optfound=""
		msg_debug "\tMatching short options."
		for argname in ${!ARG_*} ; do
			msg_debug "\t\tmatching \"$1\" to \"${!argname}\""

			# no argument
			if [ "$1" == "-${!argname}" ] ; then
				optfound="true"
				optname="CONF_${argname#ARG_}"
				optvalue="true"
				shift

			# argument is mandatory
			elif [ "${1}:" == "-${!argname}" ] ; then
				optfound="true"
				optname="CONF_${argname#ARG_}"
				optvalue="${2:-true}"
				shift 2

			# argument is optional
			elif [ "${1}::" == "-${!argname}" ] ; then
				optfound="true"
				optname="CONF_${argname#ARG_}"
				optvalue="${2:-true}"
				shift 2
			fi

			[ -n "$optfound" ] && break
		done

		# cycle through all long command-line options, search for a match
		[ -z "$optfound" ] && {
			msg_debug "\tMatching long options."
			for argname in ${!ARGL_*} ; do
				msg_debug "\t\tmatching \"$1\" to \"${!argname}\""
				if [ "${1}" == "--${!argname}" ] ; then
					optfound="true"
					optname="CONF_${argname#ARGL_}"
					optvalue="true"
					shift
				elif [ "${1}:" == "--${!argname}" ] ; then
					optfound="true"
					optname="CONF_${argname#ARGL_}"
					optvalue="${2:-true}"
					shift 2
				elif [ "${1}::" == "--${!argname}" ] ; then
					optfound="true"
					optname="CONF_${argname#ARGL_}"
					optvalue="${2:-true}"
					shift 2
				fi

				[ -n "$optfound" ] && break
			done
		}

		# check to se if we got a match
		[ -n "$optfound" ] && {
			eval ${optname}="$optvalue"
			msg_debug "\t\tMatch found! Option \"$optname\", value \"$optvalue\"."

			# check to see if we have got the configuration file option
			[ "$optname" == "CONF_CONFFILE" ] && {
				# try to load it
				[ -f "$CONF_CONFFILE" -a -r "$CONF_CONFFILE" ] && {
					msg_debug "\t\t\tLoading configuration file: \"$CONF_CONFFILE\""
					source "$CONF_CONFFILE"
				}
			}
		}
	done
}

# Print the current configuration
cmdline_msg_conf() {
	local optname
	for optname in ${!CONF_*} ; do
		echo -e "$optname=\"${!optname}\""
	done
}

# Check if everything is okay, return number of errors.
cmdline_validate() {
	local valname funcname errors_sum=0 
	for valname in ${!VAL_*} ; do
		funcname="validate_${valname#VAL_}"
		$funcname
		errors_sum=$(($errors_sum + $?))
	done

	# print the config if we were instructed to do so
	[ -n "$CONF_PRINT_CONFIG_AFTER_VALIDATE" ] && {
		cmdline_msg_conf
		exit 0
	}
	return $errors_sum
}

# EOF
