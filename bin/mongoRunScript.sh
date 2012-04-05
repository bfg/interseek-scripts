#!/bin/bash
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

###############################################################################
#				  SET GLOBALS
###############################################################################
PROG_NAME="mongoRunScript"
PROG_VERSION="trunk"

###############################################################################
#			    INCLUDE FUNCTIONS.INC.SH
###############################################################################
basedir_get() {
	local me=$(readlink -f "${0}")
	local dir=$(dirname "${me}")
	dir=$(dirname "${dir}")
	
	echo "${dir}"
}

# try to load functions
file=$(basedir_get)"/lib/interseek/sh/functions.inc.sh"
if [ ! -f "$file" ]; then
	echo "Unable to load functions file: ${file}" 1>&2
	exit 1
fi
. "$file"

# load some plugins
plugin_load date
plugin_load mongodb
plugin_load template

###############################################################################
#			  CMDLINE PLUGIN CONFIGURATION
###############################################################################
#
# command line arguments
#
ARGL_MONGO_DBNAME="mongodb-dbname:"
CONF_MONGO_DBNAME=""
HELP_MONGO_DBNAME="mongodb database name"
VAL_MONGO_DBNAME=1

ARGL_MONGO_HOSTS="mongodb-hosts:"
CONF_MONGO_HOSTS=""
HELP_MONGO_HOSTS="space-separated list of mongodb hostnames"
VAL_MONGO_HOSTS=1

ARGL_TEMPLATE="template-file:"
CONF_TEMPLATE=""
HELP_TEMPLATE="path to the template file"
VAL_TEMPLATE=1

ARGL_DATE_FROM="date-from:"
CONF_DATE_FROM="$(date_yesterday)"
HELP_DATE_FROM="date to process from, default: yesterday"
VAL_DATE_FROM=1

ARGL_DATE_TO="date-to:"
CONF_DATE_TO="$(date_yesterday)"
HELP_DATE_TO="date to process to, default: yesterday"
VAL_DATE_TO=1

ARGL_PLACEHOLDERS="placeholders:"
CONF_PLACEHOLDERS=""
HELP_PLACEHOLDERS="a comma-separated list of user-defined placeholders and their values"
VAL_PLACEHOLDERS=1

# declare the array here; if done inside a function, it gets declared locally!
declare -A CONF_PLACEHOLDERS_ARRAY 

ARGL_NO_REMOVE="no-remove"
CONF_NO_REMOVE=""
HELP_NO_REMOVE="Do not remove the processed template temporary file, useful for debugging."

ARG_DEBUG="d"
ARGL_DEBUG="debug"
CONF_DEBUG=""
HELP_DEBUG="Enable debug."

ARG_DRYRUN="n"
ARGL_DRYRUN="dryrun"
CONF_DRYRUN=""
HELP_DRYRUN="Fake execution. Don't do anything, just report what would be done."

#
# validator functions
#
validate_MONGO_HOSTS() {
	[ -z "$CONF_MONGO_HOSTS" ] && {
		msg_error "No mongodb hostnames given."
		return 1
	}

	# replace commas with whitespace
	CONF_MONGO_HOSTS="${CONF_MONGO_HOSTS//,/ }"
	return 0
}

validate_MONGO_DBNAME() {
	[ -z "$CONF_MONGO_DBNAME" ] && {
		msg_error "No mongodb database names given."
		return 1
	}
	return 0
}

validate_TEMPLATE() {
	if [ -f "$CONF_TEMPLATE" -a -r "$CONF_TEMPLATE" ] ; then
		return 0
	else
		msg_error "Template file '$CONF_TEMPLATE' does not exist."
		return 1
	fi
}

validate_DATE_FROM() {
	date_valid "$CONF_DATE_FROM" || {
		msg_error "Given from-date '$CONF_DATE_FROM' is not valid."
		return 1
	}
	return 0
}

validate_DATE_TO() {
	date_valid "$CONF_DATE_TO" || {
		msg_error "Given to-date '$CONF_DATE_TO' is not valid."
		return 1
	}
	return 0
}

validate_PLACEHOLDERS() {
	[ -z "$CONF_PLACEHOLDERS" ] && return 0

	# convert comma-separated list of placeholders to an array
	msg_debug "Placeholders from cmdline/config: '$CONF_PLACEHOLDERS'"
	msg_debug "Placeholders from array: names: '${!CONF_PLACEHOLDERS_ARRAY[*]}', values: '${CONF_PLACEHOLDERS_ARRAY[*]}"
	local p pname pvalue
	for p in ${CONF_PLACEHOLDERS//,/ } ; do
		set ${p/=/ }
		pname="$1"
		pvalue="$2"
		msg_debug "Expanded placeholder '$p' with name '$pname' and value '$pvalue'."
		CONF_PLACEHOLDERS_ARRAY["$pname"]="$pvalue"
	done
	msg_debug "Placeholders after conversion: names: '${!CONF_PLACEHOLDERS_ARRAY[*]}', values: '${CONF_PLACEHOLDERS_ARRAY[*]}'"
}

#
# help functions
#
msg_help() {
	echo "Hello, this is '$PROG_NAME' version '$PROG_VERSION'."
	cat << EOF
This program takes a script template file, processes it into a proper 
script (replacing the placeholders with variables) and runs the script 
on the MongoDB master server.

Inside the script template file, the following placeholders are
reckognized and resolved to proper values by default:
  @@DATE@@  : date for which the script is executing

Additional placeholders may be given by the '--placeholders' switch or by
setting the CONF_PLACEHOLDERS_ARRAY in the config file like so:
CONF_PLACEHOLDERS_ARRAY=( [placeholder_name]=placeholder_value )

Usage: 
  mongoRunScript [option]...

EOF
	echo -e "  Date specification:"
	cmdline_helpfor DATE_FROM
	cmdline_helpfor DATE_TO
	echo -e "  Mongo stuff:"
	cmdline_helpfor MONGO_DBNAME
	cmdline_helpfor MONGO_HOSTS
	echo -e "  Template:"
	cmdline_helpfor TEMPLATE
	cmdline_helpfor NO_REMOVE
	cmdline_helpfor PLACEHOLDERS
	echo -e "  Execution:"
	cmdline_helpfor DRYRUN
}

#
# init cmdline
#
_CMDLINE_ARGS="$*"
plugin_load cmdline || {
	msg_error "Stopping."
	exit 1
}

###############################################################################
#				      MAIN
###############################################################################
# check for dryrun
[ -n "$CONF_DRYRUN" ] && {
	msg_warn "Dryrun is in efect, faking execution."
}

# check if the date interval is valid
DATES="$(date_interval $CONF_DATE_FROM $CONF_DATE_TO)"
[ -z "$DATES" ] && {
	msg_error "Date interval from '$CONF_DATE_FROM' to '$CONF_DATE_TO' is not valid."
	exit 1
}

msg_info "================================================================================"
msg_info "MongoDB hosts: '$CONF_MONGO_HOSTS', database: '$CONF_MONGO_DBNAME'"
msg_info "Template: '$CONF_TEMPLATE'"
msg_info "Processing for dates from '$CONF_DATE_FROM' to '$CONF_DATE_TO'."
msg_info "================================================================================"

for DATE in $DATES ; do
	# buld the placeholders array from user-generated placeholders
	unset TEMPLATE_PLACEHOLDERS
	declare -A TEMPLATE_PLACEHOLDERS
	for pname in ${!CONF_PLACEHOLDERS_ARRAY[*]} ; do
		TEMPLATE_PLACEHOLDERS["$pname"]=${CONF_PLACEHOLDERS_ARRAY["$pname"]}
	done

	# append the @@DATE@@ placeholder (internal to mongoRunScript)
	TEMPLATE_PLACEHOLDERS["@@DATE@@"]="$DATE"

	# process the template to obtain an executable script
	script="$(template_process $CONF_TEMPLATE)"
	[ $? -gt 0 ] && {
		msg_error "Could not process template '$CONF_TEMPLATE', aborting."
		exit 1
	}

	# run... unless we are faking execution
	msg_info "Now processing for date '$DATE'"
	t_start="$(date +%s)"
	if [ -z "$CONF_DRYRUN" ] ; then
		MONGODB_FAKE=""
		mongodb_runscript "$script" "$CONF_MONGO_DBNAME" "$CONF_MONGO_HOSTS"
		retval=$?
	else
		MONGODB_FAKE="1"
		mongodb_runscript "$script" "$CONF_MONGO_DBNAME" "$CONF_MONGO_HOSTS"
		retval=$?
	fi
	t_end="$(date +%s)"
	t_elapsed=$(( $t_end - $t_start ))

	# check for injuries
	if [ $retval -eq 0 ] ; then
		msg_info "Operation done successfuly in $t_elapsed second(s)."
	else
		msg_error "Operation FAILED."
	fi

	# cleanup and exit
	if [ -z "$CONF_NO_REMOVE" ] ; then
		tempfile_remove "$script"
		[ $? -gt 0 ] && {
		msg_error "Could not remove script: '$script'."
			exit 1
		}
	else
		msg_info "Not removing script: '$script'."
	fi
done
exit $retval
