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
PROG_NAME="mongoPruneCollections"
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

ARGL_DATE_FROM="keep-date-from:"
CONF_DATE_FROM=""
HELP_DATE_FROM="Keep collections from this date, no default."
VAL_DATE_FROM=1

ARGL_DATE_TO="keep-date-to:"
CONF_DATE_TO=""
HELP_DATE_TO="Keep collections to this date, no default."
VAL_DATE_TO=1

ARGL_COL_REGEXP="col-regexp:"
CONF_COL_REGEXP=""
HELP_COL_REGEXP="Collection names must match this regexp to be considered for dropping."
VAL_COL_REGEXP=1

ARG_DEBUG="d"
ARGL_DEBUG="debug"
CONF_DEBUG=""
HELP_DEBUG="Enable debug."

ARG_REALRUN="Y"
CONF_REALRUN=""
HELP_REALRUN="*REALLY* drop the collections, default is not to do anything."

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

validate_COL_REGEXP() {
	[ -z "$CONF_COL_REGEXP" ] && {
		msg_error "No collection regexp given."
		return 1
	}
	return 0
}

#
# help functions
#
msg_help() {
	echo "Hello, this is '$PROG_NAME' version '$PROG_VERSION'."
	cat << EOF
This program drops collections form a given MongoDB database. It considers
all collections that were given by the --col-regexp switch for dropping,
and drops only those that are outside of the --keep-date-from and
--keep-date-to interval.

Usage: 
  mongoPruneCollections.sh [option]...

EOF
	echo -e "  Collection name specification:"
	cmdline_helpfor COL_REGEXP
	echo -e "  Date specification:"
	cmdline_helpfor DATE_FROM
	cmdline_helpfor DATE_TO
	echo -e "  Mongo stuff:"
	cmdline_helpfor MONGO_DBNAME
	cmdline_helpfor MONGO_HOSTS
	echo -e "  Execution:"
	cmdline_helpfor REALRUN
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
[ -z "$CONF_REALRUN" ] && {
	msg_warn "Realrun is *not* in effect, faking execution."
}

# check if the date interval is valid
DATES="$(date_interval $CONF_DATE_FROM $CONF_DATE_TO)"
[ -z "$DATES" ] && {
	msg_error "Date interval from '$CONF_DATE_FROM' to '$CONF_DATE_TO' is not valid."
	exit 1
}

msg_info "================================================================================"
msg_info "MongoDB hosts: '$CONF_MONGO_HOSTS', database: '$CONF_MONGO_DBNAME'"
msg_info "Keeping collections named '$CONF_COL_REGEXP' for dates from '$CONF_DATE_FROM' to '$CONF_DATE_TO'."
msg_info "================================================================================"

# get collections to consider
COLS=$(mongodb_list_collections $CONF_MONGO_DBNAME $CONF_MONGO_HOSTS | grep -P "$CONF_COL_REGEXP" | sort)

# generate grep file and do the grep
GREP_FILE=$(tempfile_create)
for d in $DATES ; do
	echo $d >> $GREP_FILE
done
COLS_TODO="$(echo "$COLS" | grep -v -f $GREP_FILE | sed ':a;$!{N;ba};s/\n/ /g')"

# do tha work
for col in $COLS_TODO ; do
	if [ -z "$CONF_REALRUN" ] ; then
		MONGODB_FAKE="true"
		msg_info "Would drop collection '$col'"
		mongodb_drop_collection "$col" "$CONF_MONGO_DBNAME" $CONF_MONGO_HOSTS
	else
		MONGODB_FAKE=""
		mongodb_drop_collection "$col" "$CONF_MONGO_DBNAME" $CONF_MONGO_HOSTS
		retval="$?"
		if [ $retval -eq 0 ] ; then
			msg_info "Dropped collection: '$col'"
		else
			msg_error "Could not drop collection: '$col'."
		fi
	fi
done

# cleanup and exit
tempfile_remove $GREP_FILE
exit 0
