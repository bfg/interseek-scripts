#!/bin/bash

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
_MONGODB_VERSION="trunk"

# mongodb shell binary, leave empty to autodetect
MONGODB_SHELL=""
MONGODB_SHELL_ARGS="--quiet"

# set this to any value to fake execution
MONGODB_FAKE=""

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################
mongodb_version() {
	echo $_MONGODB_VERSION
}

mongodb_init() {
	MONGODB_SHELL="${MONGODB_SHELL:-$(which mongo)}" || {
		msg_error "No mongo shell found."
		return 1
	}
	msg_debug "Using mongodb shell: '$MONGODB_SHELL'"
	return 0
}

mongodb_is_master() {
	local hostname="$1"
	[ -z "$hostname" ] && {
		msg_debug "No hostname given."
		return 1;
	}
	local response="$(echo 'db.serverStatus();' | $MONGODB_SHELL $hostname | grep -i 'ismaster.*true')"
	if [ -z "$response" ] ; then
		msg_debug "Host '$hostname' is not master."
		return 1
	else
		msg_debug "Host '$hostname' is master."
		return 0
	fi
}

mongodb_get_master() {
	local hostnames="$@"
	local master h
	for h in $hostnames ; do
		mongodb_is_master "$h" && {
			master="$h"
			break
		}
	done
	if [ -z "$master" ] ; then
		msg_debug "No master found from hostlist '$hostnames'"
		return 1
	else
		msg_debug "Found mongodb master '$master'."
		echo "$master"
		return 0
	fi
}

mongodb_runscript() {
	local script="$1"
	shift
	
	# check to see if we are in STDIN mode
	local stdin_mode
	[ "$script" == '-' ] && {
		stdin_mode="true"
	}

	# if we are not in stdin mode, check to see if the script exists
	[ -z "$stdin_mode" ] && {
		[ ! -r "$script" -o ! -f "$script" ] && {
			msg_debug "Cannot read script '$script', aborting."
			exit 1
		}
	}	

	# check for database
	local database="$1"
	shift
	[ -z "$database" ] && {
		msg_debug "No database given, aborting."
		exit 1
	}

	# check hostnames
	local hostnames=$@
	[ -z "$hostnames" ] && {
		msg_debug "No hostnames given, aborting."
		exit 1
	}

	# get mongodb master
	local mongodb_master
	master=$(mongodb_get_master $hostnames)
	[ $? -ne 0 ] && {
		msg_debug "No mongodb master could be found from hostlist '$hostnames', aborting."
		exit 1
	}

	# build the run string according to STDIN mode
	local run stdin
	if [ -z "$stdin_mode" ] ; then
		run="$MONGODB_SHELL $MONGODB_SHELL_ARGS ${master}/${database} $script"
	else
		stdin="$(cat -)"
		run="echo '$stdin' | $MONGODB_SHELL $MONGODB_SHELL_ARGS ${master}/${database}"
	fi

	# run according to fakeness and STDIN mode
	local retval
	if [ -z "$MONGODB_FAKE" ] ; then
		msg_debug "Running: '$run'"
		if [ -z "$stdin_mode" ] ; then
			eval $run 2>&1 > /dev/null 
			retval=$?
		else
			eval $run  # user expects to see the result on STDOUT 
			retval=$?
		fi
		return $retval
	else
		msg_debug "Would run: '$run'"
		return 0
	fi
}

mongodb_list_collections() {
	local collections temp
	temp="$MONGODB_SHELL_ARGS"
	collections=$(echo 'show collections;' | mongodb_runscript '-' $@ | tail -n +2 | head -n -1)
	if [ $? -eq 0 ] ; then
		echo "$collections"
		return 0
	else
		return 1
	fi
}

mongodb_drop_collection() {
	local col="$1" ; shift
	[ -z "$col" ] && {
		msg_debug "No collection name given, aborting."
		return 1
	}

	local db="$1"; shift
	[ -z "$db" ] && {
		msg_debug "No database name given, aborting."
		return 1
	}
	
	local hosts=$@
	[ -z "$hosts" ] && {
		msg_debug "No hosts given, aborting."
		return 1
	}
	
	local retval result
	result=$(echo "db.${col}.drop();" | mongodb_runscript '-' "$db" $hosts)
	retval=$?

	# check for injuries
	if [ $retval -ne 0 ] ; then
		# something went wrong; return what we've got fro the mongodb_runscript
		msg_debug "Could not drop collection '$col' in database '$db' on '$hosts', mongodb shell returned: '$retval'"
		return $retval
	else
		# return 0 if and only if we have successfuly dropped the collection
		if echo "$result" | grep 'true' 2>&1 > /dev/null; then
			msg_debug "Collection: '$col' in database '$db' on '$hosts' dropped OK."
			return 0
		else
			msg_debug "Could not drop collection: '$col' in database '$db' on '$hosts', mongodb shell returned: '$retval'"
			return 1
		fi
	fi
}
