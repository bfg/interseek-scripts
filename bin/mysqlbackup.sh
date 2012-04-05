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

#####################################################################
#                         INCLUDE FUNCTIONS.INC.SH                  #
#####################################################################
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

#####################################################################
#                  CMDLINE CONFIGURATION                            #
#####################################################################
#
# general stuff
#
ARG_DRYRUN="n"
ARGL_DRYRUN="dryrun"
CONF_DRYRUN=""
HELP_DRYRUN="Dry run. Don't do anything tricky."

#
# program dependencies
#
# rsync
ARGL_RSYNC="rsync:"
CONF_RSYNC=""
HELP_RSYNC="<path>\tPath to rsync executable."
VAL_RSYNC=1

# rsync arguments
ARGL_RSYNC_ARGS="rsync-args:"
CONF_RSYNC_ARGS=""
HELP_RSYNC_ARGS="<args>\tArguments."

# mysqldump
ARGL_MYSQLDUMP="mysqldump:"
CONF_MYSQLDUMP=""
HELP_MYSQLDUMP="<path>\tPath to mysqldump executable."
VAL_MYSQLDUMP=1

# mysqldump arguments
ARGL_MYSQLDUMP_ARGS="mysqldump-args:"
CONF_MYSQLDUMP_ARGS=""
HELP_MYSQLDUMP_ARGS="<args>\tArguments."

# mysqlhotcopy
ARGL_MYSQLHOTCOPY="mysqlhotcopy:"
CONF_MYSQLHOTCOPY=""
HELP_MYSQL_HOTCOPY="<path>\tPath to mysqlhotcopy executable."
VAL_MYSQL_HOTCOPY=1

# mysqlhotcopy arguments
ARGL_MYSQLHOTCOPY_ARGS="mysqlhotcopy-args:"
CONF_MYSQLHOTCOPY_ARGS=""
HELP_MYSQLHOTCOPY_ARGS="<args>\tArguments."

#
# database stuff
#
# database method 
ARG_DB_METHOD="m:"
ARGL_DB_METHOD="db-method:"
CONF_DB_METHOD=""
HELP_DB_METHOD="mysqldump | mysqlhotcopy\tBackup method."
VAL_DB_METHOD=1

# database socket
ARG_DB_SOCKET="S:"
ARGL_DB_SOCKET="db-socket:"
CONF_DB_SOCKET=""
HELP_DB_SOCKET="<path>\tMySQL socket path."
VAL_DB_SOCKET=1

# database host
ARG_DB_HOST="H:"
ARGL_DB_HOST="db-host:"
CONF_DB_HOST=""
HELP_DB_HOST="<hostname>\tHostname of the MySQL server. If none is given, connect through socket."

# database user
ARG_DB_USER="u:"
ARGL_DB_USER="db-user:"
CONF_DB_USER=""
HELP_DB_USER="<username>\tMySQL username."
VAL_DB_USER=1

# datbase password
ARG_DB_PASSWORD="p:"
ARGL_DB_PASSWORD="db-password:"
CONF_DB_PASSWORD=""
HELP_DB_PASSWORD="<password>\tMySQL password."
VAL_DB_PASSWORD=1

# database names
ARG_DB_NAMES="D:"
ARGL_DB_NAMES="db-names:"
CONF_DB_NAMES=""
HELP_DB_NAMES="<db1,db2,...>\tNames of the databases you'd like to backup. If left empty, all databases get backed up."
VAL_DB_NAMES=1

# database port
ARGL_DB_PORT="db-port:"
CONF_DB_PORT="3306"
HELP_DB_PORT="<port>\tMySQL port."

#
# output configuration
#
# target
ARG_TARGET="t:"
ARGL_TARGET="target:"
CONF_TARGET=""
HELP_TARGET="<something>\tTarget. It can be a filesystem path or rsync address. I will try to figure out what you meant."
VAL_TARGET=1

# target gzip
ARG_TARGET_GZIP="g"
ARGL_TARGET_GZIP="gzip"
CONF_TARGET_GZIP=""
HELP_TARGET_GZIP="Gzip the output."

# target overwrite
ARG_TARGET_OVERWRITE="o"
ARGL_TARGET_OVERWRITE="overwrite"
CONF_TARGET_OVERWRITE=""
HELP_TARGET_OVERWRITE="Overwrite output."

# target type
ARGL_TARGET_TYPE="target-type:"
CONF_TARGET_TYPE=""
HELP_TARGET_TYPE="local | rsync | rsync-server\tTarget type."
VAL_TARGET_TYPE=1

# target path
ARGL_TARGET_PATH="target-path:"
CONF_TARGET_PATH=""
HELP_TARGET_PATH="<path>\tTarget path."
VAL_TARGET_PATH=1

# target suffix
ARGL_TARGET_SUFFIX="target-suffix:"
CONF_TARGET_SUFFIX=""
HELP_TARGET_SUFFIX="<suffix>\tTarget suffix."

# target timestamp
ARGL_TARGET_TIMESTAMP="target-timestamp"
CONF_TARGET_TIMESTAMP=""
HELP_TARGET_TIMESTAMP="Append a timestamp to target filename."

# target rsync host
ARGL_TARGET_RSYNC_HOST="target-host:"
CONF_TARGET_RSYNC_HOST=""
HELP_TARGET_RSYNC_HOST="<hostname>\tRemote target hostname."
VAL_TARGET_RSYNC_HOST=1

# target rsync user
ARGL_TARGET_RSYNC_USER="target-user:"
CONF_TARGET_RSYNC_USER=""
HELP_TARGET_RSYNC_USER="<username>\tRemote target username."
VAL_TARGET_RSYNC_USER=1

# target rsync password
ARGL_TARGET_RSYNC_PASSWORD="target-password:"
CONF_TARGET_RSYNC_PASSWORD=""
HELP_TARGET_RSYNC_PASSWORD="<password>\tRemote target password."
VAL_TARGET_RSYNC_PASSWORD=1

# program stuff
PROG_NAME="mysqlbackup"
PROG_VERSION="trunk"

#####################################################################
#                            HELP                                   #
#####################################################################
msg_help() {
	echo "Hello, this is $PROG_NAME version $PROG_VERSION"
	cat << EOF
This program is a wrapper around mysqldump(1), mysqlhotcopy(1) and rsync(1).
It can dump databases from a local or remote MySQL server, optionally compress 
and encrypt the output file and store it on a local filesystem location or
pump it to a remote location using rsync(1).

What it needs to know from you is where to dump the database from and where
to put the output file to.

Usage: 
  mysqldump [option]...

Valid options are:
EOF
	echo -e "  Input:"
	cmdline_helpfor DB_METHOD
	cmdline_helpfor DB_SOCKET
	cmdline_helpfor DB_HOST
	cmdline_helpfor DB_PORT
	cmdline_helpfor DB_USER
	cmdline_helpfor DB_PASSWORD
	cmdline_helpfor DB_NAMES
	
	echo -e "  Output:"
	cmdline_helpfor TARGET
	echo -e "      If target is left unset, you can use the following options:" 
	cmdline_helpfor TARGET_TYPE
	cmdline_helpfor TARGET_PATH
	cmdline_helpfor TARGET_RSYNC_HOST
	cmdline_helpfor TARGET_RSYNC_USER
	cmdline_helpfor TARGET_RSYNC_PASSWORD

	cmdline_helpfor TARGET_GZIP
	cmdline_helpfor TARGET_OVERWRITE
	cmdline_helpfor TARGET_SUFFIX
	cmdline_helpfor TARGET_TIMESTAMP

	echo -e "  Program dependencies:"
	cmdline_helpfor RSYNC
	cmdline_helpfor RSYNC_ARGS
	cmdline_helpfor MYSQLDUMP
	cmdline_helpfor MYSQLDUMP_ARGS
	cmdline_helpfor MYSQLHOTCOPY
	cmdline_helpfor MYSQLHOTCOPY_ARGS
}

#####################################################################
#                 CMDLINE VALIDATOR FUNCTIONS                       #
#####################################################################
# Define the validator functions (for cmdline_validate), validator function
# should return 0 on success, 1 or greater on error.

# This should always get set.
validate_RSYNC() {
	# check for rsync presence
	[ "$CONF_RSYNC" == "" ] && {
		CONF_RSYNC="$(which rsync 2>&1)"
		local retval=$?
		[ $retval -ne 0 ] && {
			msg_error "You didn't give an rsync executable path and none was found automagically."
			return 1
		}
	}

	# check for rsync presence and executabilty
	[ ! -x "$CONF_RSYNC" ] && {
		msg_error "No rsync executable found at \"$CONF_RSYNC\"."
		return 1
	}

	return 0
}

# This should always get set.
validate_MYSQLDUMP() {
	# try to make up something if this is left unset
	if [ -z "$CONF_MYSQLDUMP" ] ; then
		CONF_MYSQLDUMP=$(which mysqldump)
		if [ $? -ne 0 ] ; then
			# do this as a last resort
			CONF_MYSQLDUMP="/export/software/mysql/bin/mysqldump"
		fi
	fi

	# do the test
	if [ ! -x "$CONF_MYSQLDUMP" ] ; then
		msg_error "No mysqldump found in: \"$CONF_MYSQLDUMP\"."
		return 1
	else
		return 0
	fi
}

# This should always get set.
validate_MYSQL_HOTCOPY() {
	# try to make up something if this is left unset
	if [ -z "$CONF_MYSQLHOTCOPY" ] ; then
		CONF_MYSQLHOTCOPY=$(which mysqlhotcopy)
		if [ $? -ne 0 ] ; then
			# do this as a last resort
			CONF_MYSQLHOTCOPY="/export/software/mysql/bin/mysqlhotcopy"
		fi
	fi

	# do the test
	if [ ! -x "$CONF_MYSQLHOTCOPY" ] ; then
		msg_error "No mysqlhotcopy found in: \"$CONF_MYSQLHOTCOPY\"."
		return 1
	else
		return 0
	fi
}

# This should always get set.
validate_DB_METHOD() {
	if [ -z "$CONF_DB_METHOD" ]  ; then
		msg_error "No backup method given."
		return 1
	elif [ "$CONF_DB_METHOD" == "mysqlhotcopy" -o "$CONF_DB_METHOD" == "mysqldump" ]  ; then
		return 0
	else
		msg_error "Unknown backup method: \"$CONF_DB_METHOD\"."
		return 1
	fi
}

# Optional.
validate_DB_SOCKET() {
	if [ -z "$CONF_DB_HOST" ] ; then 
		# Ok, CONF_DB_SOCKET is in effect
		if [ -z "$CONF_DB_SOCKET" ] ; then
			msg_error "No MySQL socket given."
			return 1
		fi
		if [ ! -e "$CONF_DB_SOCKET" ] ; then
			msg_error "Socket \"$CONF_DB_SOCKET\" does not exist."
			return 1
		fi
		if [ ! -S "$CONF_DB_SOCKET" ] ; then
			msg_error "\"$CONF_DB_SOCKET\" is not a socket."
			return 1
		fi
		if [ ! -r "$CONF_DB_SOCKET" ] ; then
			msg_error "\"$CONF_DB_SOCKET\" is not readable."
			return 1
		fi
		if [ ! -w "$CONF_DB_SOCKET" ] ; then
			msg_error "\"$CONF_DB_SOCKET\" is not writable."
			return 1
		fi
		return 0
	else
		# No, CONF_DB_SOCKET should get ignored
		if [ -n "$CONF_DB_SOCKET" ] ; then
			msg_error "Both MySQL hostname and MySQL socket specified."
			return 1
		else
			return 0
		fi
	fi
}

# Optional.
validate_DB_USER() {
	if [ -z "$CONF_DB_USER" ] ; then
		msg_warn "No database user given."
	fi
	return 0
}

# Optional.
validate_DB_NAMES() {
	if [ -z "$CONF_DB_NAMES" ] ; then
		msg_warn "No database names given, assuming all databases."
	fi
	return 0
}

# Optional.
validate_DB_PASSWORD() {
	if [ -z "$CONF_DB_PASSWORD" ] ; then
		msg_warn "No database password given."
	fi
	return 0
}

# Do some magic here.
validate_TARGET() {
	# check if the target was given at all
	if [ -z "$CONF_TARGET" ] ; then
		msg_warn "No target given, will check other options."
		return 0
	else
		# figure out the target type: local, rsync or rsync-server? 
		# e.g. /tmp, urosg@localhost:/tmp, urosg@localhost::tmp
		# do we have a rsync server?
		if echo "$CONF_TARGET" | grep -q '::' ; then
			CONF_TARGET_TYPE="rsync-server"
			# check for username, maybe we dont have it
			if echo "$CONF_TARGET" | grep -q '@' ; then
				CONF_TARGET_RSYNC_USER="$(echo $CONF_TARGET | cut -f1 -d@)"
			else
				CONF_TARGET_RSYNC_USER=""
			fi
			CONF_TARGET_PATH="$(echo $CONF_TARGET | awk 'BEGIN { FS="::" } { print $2 }')"
			# get rid of the path portion
			CONF_TARGET_RSYNC_HOST="${CONF_TARGET%%::${CONF_TARGET_PATH}}"
			# get rid of the username portion if we actually have it
			if [ -n "$CONF_TARGET_RSYNC_USER" ] ; then
				CONF_TARGET_RSYNC_HOST="${CONF_TARGET_RSYNC_HOST##${CONF_TARGET_RSYNC_USER}@}"
			fi
			msg_debug "Target is rsync-server, host: \"$CONF_TARGET_RSYNC_HOST\", user: \"$CONF_TARGET_RSYNC_USER\", path: \"$CONF_TARGET_PATH\"."
		# do we have rsync?
		elif echo "$CONF_TARGET" | grep -q ':' ; then  
			CONF_TARGET_TYPE="rsync"
			# check for username, maybe we dont have it
			if echo "$CONF_TARGET" | grep -q '@' ; then
				CONF_TARGET_RSYNC_USER="$(echo $CONF_TARGET | cut -f1 -d@)"
			else
				CONF_TARGET_RSYNC_USER=""
			fi
			CONF_TARGET_PATH="$(echo $CONF_TARGET | cut -f2 -d:)"
			# get rid of the path portion
			CONF_TARGET_RSYNC_HOST="${CONF_TARGET%%:${CONF_TARGET_PATH}}"
			# get rid of the username portion if we actually have it
			if [ -n "$CONF_TARGET_RSYNC_USER" ] ; then
				CONF_TARGET_RSYNC_HOST="${CONF_TARGET_RSYNC_HOST##${CONF_TARGET_RSYNC_USER}@}"
			fi
			msg_debug "Target is rsync, host: \"$CONF_TARGET_RSYNC_HOST\", user: \"$CONF_TARGET_RSYNC_USER\", path: \"$CONF_TARGET_PATH\"."
		# we have local target
		else
			CONF_TARGET_TYPE="local"
			CONF_TARGET_PATH="$CONF_TARGET"
			msg_debug "Target is local, path: \"$CONF_TARGET\"."
		fi
		return 0
	fi
}

# CONF_TARGET_TYPE should always get set, one way or another
validate_TARGET_TYPE() {
	# check for contents
	if [ -z "$CONF_TARGET_TYPE" ] ; then
		msg_error "No target type given."
		return 1
	else
		case $CONF_TARGET_TYPE in
			rsync)
				return 0
			;;
			rsync-server)
				return 0
			;;
			local)
				return 0
			;;
			*)
				msg_error "Unknown target type: \"$CONF_TARGET_TYPE\"."
				return 1
			;;
		esac
	fi
}

# This should only be left unset if the target is local
validate_TARGET_RSYNC_HOST() {
	# check for contents
	if [ -z "$CONF_TARGET_RSYNC_HOST" -a "$CONF_TARGET_TYPE" != "local" ] ; then
		msg_error "No target hostname given."
		return 1
	else
		return 0
	fi
}

# Optional.
validate_TARGET_RSYNC_USER() {
	# check for contents
	if [ -z "$CONF_TARGET_RSYNC_USER" ] ; then
		case $CONF_TARGET_TYPE in
			rsync|rsync-server)
				msg_warn "No target username given."
			;;
		esac
	fi
	return 0
}

# Optional.
validate_TARGET_RSYNC_PASSWORD() {
	if [ -z "$CONF_TARGET_RSYNC_PASSWORD" ] ; then
		case $CONF_TARGET_TYPE in
			rsync|rsync-server)
				msg_warn "No target password given."
			;;
		esac
	fi
	return 0
}

# Optional.
validate_TARGET_PATH() {
	# do this only if CONF_TARGET is not set
	if [ -n "$CONF_TARGET" ] ; then
		return 0
	fi
	# check for contents
	if [ -z "$CONF_TARGET_PATH" ] ; then
		msg_error "No target path."
		return 1
	else
		return 0
	fi
}

validate_TARGET_GZIP() {
	return 0
}

validate_TARGET_OVERWRITE() {
	return 0
}

validate_TARGET_SUFFIX() {
	return 0
}

validate_TARGET_TIMESTAMP() {
	return 0
}

#####################################################################
#                    CMDLINE INITIALIZATION                         #
#####################################################################
# try to load cmdline
_CMDLINE_ARGS="$@"
plugin_load cmdline

#file=$(basedir_get)"/lib/interseek/sh/cmdline.inc.sh"
#if [ ! -f "$file" ]; then
#	echo "Unable to load cmdline file: ${file}" 1>&2
#	exit 1
#fi
#. "$file"
#cmdline_init $*
#cmdline_validate || {
#	msg_error "$? errors found while validating config, aboring"
#	exit 1
#}

#####################################################################
#                    APPLICATION FUNCTIONS                          #
#####################################################################
create_tempfile() {
	mktemp -t "${PROG_NAME}.XXXXXXX"
	return $?
}

remove_tempfile() {
	local file="$1"
	if [ -n "$file" ] ; then
		rm -f "$file" > /dev/null 2>&1
		return $?
	else
		msg_error "No file given."
		return 1
	fi
}

create_tempdir() {
	local retval
	mktemp -d -t "${PROG_NAME}.XXXXXXX"
	retval=$?
	if [ $retval -ne 0 ] ; then
		msg_error "Could not create tempdir."
	fi
	return $retval
}

remove_tempdir() {
	local dirname="$1"
	if [ -n "$dirname" ] ; then
		rm -rf "$dirname" > /dev/null 2>&1
		return $?
	else
		msg_error "No directory given."
		return 1
	fi
}

mysqldump_local() {
	local jobid=$RANDOM
	msg_info "[JOB-${jobid}] Starting local mysqldump job."

	# honor output filename modifiers
	CONF_TARGET_PATH="${CONF_TARGET_PATH}${CONF_TARGET_TIMESTAMP:+$(date "+%Y%m%d-%H%M%S")}${CONF_TARGET_SUFFIX}"

	# check if the target already exists
	msg_debug "[JOB-${jobid}] Checking if the target \"$CONF_TARGET_PATH\" already exists."
	if [ -e "$CONF_TARGET_PATH" ] ; then
		# run some additional checks
		[ -z "$CONF_TARGET_OVERWRITE" ] && {
			msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists. Not instructed to overwrite. Aborting!"
			return 1
		}
		[ ! -f "$CONF_TARGET_PATH" ] && {
			msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists but is not a regular file, aborting!"
			return 1
		}
		[ ! -w "$CONF_TARGET_PATH" ] && {
			msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists but is not writable, aborting!"
			return 1
		}
	else
		# check if the target directory is writable
		local option_target_path_parentdir=$(dirname $CONF_TARGET_PATH)
		msg_debug "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" does not exist. Checking if the targets parent dir \"$option_target_path_parentdir\" is writable."
		if [ ! -w "$option_target_path_parentdir" ] ; then
			msg_error "[JOB-${jobid}] Targets parent dir \"$option_target_path_parentdir\" is not writable, aborting!"
			return 1
		fi
	fi

	# prepare command line, we need to do some fancy expansion in case some 
	# arguments are not given
	#local mysqldump_run=$(echo ${CONF_MYSQLDUMP} ${CONF_MYSQLDUMP_ARGS} ${CONF_DB_SOCKET:+--socket=$CONF_DB_SOCKET} ${CONF_DB_HOST:+--host=$CONF_DB_HOST} ${CONF_DB_PORT:+--port=$CONF_DB_PORT} ${CONF_DB_USER:+--user=$CONF_DB_USER} ${CONF_DB_PASSWORD:+--password=$CONF_DB_PASSWORD} ${CONF_DB_NAMES:---all-databases} ${CONF_TARGET_GZIP:+| gzip} ">" $CONF_TARGET_PATH)
	local mysqldump_run=$(echo \
		${CONF_MYSQLDUMP} \
		${CONF_DB_SOCKET:+--socket=${CONF_DB_SOCKET}} \
		${CONF_DB_HOST:+--host=${CONF_DB_HOST}} \
		${CONF_DB_PORT:+--port=${CONF_DB_PORT}} \
		${CONF_DB_USER:+--user=${CONF_DB_USER}} \
		${CONF_DB_PASSWORD:+--password=${CONF_DB_PASSWORD}} \
		${CONF_DB_NAMES:---all-databases} \
		${CONF_MYSQLDUMP_ARGS} \
		${CONF_TARGET_GZIP:+| gzip} \
		">" \
		$CONF_TARGET_PATH \
	)

	# Just do it...
	msg_info "[JOB-${jobid}] Running mysqldump, cmdline is: \"$mysqldump_run\"."
	# XXX: this thing really needs to be done like this or else the result value is eaten away by intermediate command(s)
	local mysqldump_output mysqldump_retval
	if [ -z "$CONF_DRYRUN" ] ; then
		mysqldump_output=$(eval ${mysqldump_run} 2>&1)
		mysqldump_retval=$?
	else
		mysqldump_output=""
		mysql_retval=0
	fi

	# check for injuries. We cannot safely check for the return value of the mysqldump command
	# since it is replaced by gzip if the user instructed us to gzip the output
	if [ -z "$mysqldump_output" ] ; then
		msg_info "[JOB-${jobid}] Local mysqldump job completed successfully."
		return 0
	else
		msg_error "[JOB-${jobid}] Job failed, reason: \"$mysqldump_output\"."
		return 1
	fi
}

mysqldump_rsync() {
	local jobid=$RANDOM
	msg_info "[JOB-${jobid}] Starting remote mysqldump job"

	# honor output filename modifiers
	CONF_TARGET_PATH="${CONF_TARGET_PATH}${CONF_TARGET_TIMESTAMP:+$(date "+%Y%m%d-%H%M%S")}${CONF_TARGET_SUFFIX}"
	# reset the filename modifiers
	CONF_TARGET_TIMESTAMP=""
	CONF_TARGET_SUFFIX=""

	# Figure up a tempfile
	msg_debug "[JOB-${jobid}] Making up a tempfile"
	local tmpfile
	tmpfile=$(create_tempfile)
	if [ $? -ne 0 ] ; then
		msg_error "[JOB-${jobid}] Could not create tempfile, aborting."
		return 1
	else
		msg_debug "[JOB-${jobid}] Tempfile is: \"$tmpfile\"."
	fi

	# switch variables to fool mysqldump_local, set overwrite to on, change target path to local
	# tempfile
	local switch_target_overwrite_backup=$CONF_TARGET_OVERWRITE
	CONF_TARGET_OVERWRITE="yes"
	local option_target_path_backup=$CONF_TARGET_PATH
	CONF_TARGET_PATH="$tmpfile"

	# attempt local mysqldump job
	msg_debug "[JOB-${jobid}] Attempting local mysqldump job."
	mysqldump_local || {
		msg_error "[JOB-${jobid}] Remote mysqldump job failed because local mysqldump job failed."
		remove_tempfile "$tmpfile"
		return 1
	}

	# restore vars
	CONF_TARGET_PATH=$option_target_path_backup
	CONF_TARGET_OVERWRITE=$option_target_overwrite_backup

	# prepare command line, we need to do some fancy expansion in case some 
	# arguments are not given
	local rsync_run
	case "$CONF_TARGET_TYPE" in
	rsync)
		rsync_run=$(echo \
			$CONF_RSYNC \
			$CONF_RSYNC_ARGS \
			$tmpfile \
			"${CONF_TARGET_RSYNC_USER:+${CONF_TARGET_RSYNC_USER}@}${CONF_TARGET_RSYNC_HOST}:${CONF_TARGET_PATH}"
		)
		;;
	rsync-server)
		rsync_run=$(echo \
			$CONF_RSYNC \
			$CONF_RSYNC_ARGS \
			$tmpfile \
			"${CONF_TARGET_RSYNC_USER:+${CONF_TARGET_RSYNC_USER}@}${CONF_TARGET_RSYNC_HOST}::${CONF_TARGET_PATH}"
		)
		;;
	*)
		msg_error "[JOB-${jobid}] Don't know how to handle rsync target \"${CONF_TARGET_TYPE}\", aborting."
		remove_tempfile "$tmpfile"
		return 1
		;;
	esac
	
	# Just do it...
	msg_info "[JOB-${jobid}] rsyncing to remote location: \"${rsync_run}\"."
	# XXX: this thing really needs to be done like this or else the result value is eaten away by intermediate command(s)
	local rsync_output rsync_retval
	if [ -z "$CONF_DRYRUN" ] ; then
		rsync_output=$(export RSYNC_PASSWORD="$CONF_TARGET_RSYNC_PASSWORD" ; eval ${rsync_run} 2>&1)
		rsync_retval=$?
	else
		rsync_output=""
		rsync_retval=0
	fi

	# remove tempfile and check for injuries
	remove_tempfile "$tmpfile"
	if [ $rsync_retval -ne 0 ] ; then
		msg_error "[JOB-${jobid}] rsync failed, exit status \"$rsync_retval\", reason: \"$rsync_output\"."
		msg_error "[JOB-${jobid}] Job failed."
		return 1
	else
		msg_info "[JOB-${jobid}] Remote mysqldump job completed successfully."
		return 0
	fi
}

mysqlhotcopy_local() {
	local jobid=$RANDOM
	msg_info "[JOB-${jobid}] Starting job. Method is mysqlhotcopy, target is local."

	# honor output filename modifiers
	CONF_TARGET_PATH="${CONF_TARGET_PATH}${CONF_TARGET_TIMESTAMP:+$(date "+%Y%m%d-%H%M%S")}${CONF_TARGET_SUFFIX}"

	# Check if the target already exists. This gets ugly since we do have two
	# target types: a dir or a file.
	msg_debug "[JOB-${jobid}] Checking if the target \"$CONF_TARGET_PATH\" already exists."
	local option_target_path_parentdir
	option_target_path_parentdir=$(dirname $CONF_TARGET_PATH) || {
		msg_error "[JOB-${jobid}] Could not get parent dir path from \"$CONF_TARGET_PATH\", aborting."
		return 1
	}
	if [ -n "$CONF_TARGET_GZIP" ] ; then
		# Target is a gzipped tar archive, check if it already exists
		if [ -e "$CONF_TARGET_PATH" ] ; then
			# run some additional checks
			[ -z "$CONF_TARGET_OVERWRITE" ] && {
				msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists. Not instructed to overwrite. Aborting!"
				return 1
			}
			[ ! -f "$CONF_TARGET_PATH" ] && {
				msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists but is not a file. Don't know what you want me to do in this case, aborting!"
				return 1
			}
			[ ! -w "$CONF_TARGET_PATH" ] && {
				msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists but is not writable, aborting!"
				return 1
			}
			# remove target
			msg_info "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists, removing it."
			rm "$CONF_TARGET_PATH" > /dev/null 2>&1 || {
				msg_error "[JOB-{$jobid}] Could not remove existing target \"$CONF_TARGET_PATH\", aborting!"
				exit 1
			}
		else
			msg_debug "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" does not exist."
		fi

		# check if the parent's target directory is writable
		msg_debug "[JOB-${jobid}] Checking if the targets parent dir \"$option_target_path_parentdir\" is writable."
		[ ! -w "$option_target_path_parentdir" ] && {
			msg_error "[JOB-${jobid}] Targets parent dir \"$option_target_path_parentdir\" is not writable, aborting!"
			return 1
		}

		# We will dump the db contents to a tempdir. Figure it out.
		msg_debug "[JOB-${jobid}] Making up a tempdir."
		local tmpdir
		tmpdir=$(create_tempdir)
		if [ $? -ne 0 ] ; then
			msg_error "[JOB-${jobid}] Could not create tempdir, aborting."
			return 1
		else
			msg_debug "[JOB-${jobid}] Tempdir is: \"$tmpdir\"."
		fi

		# Switch vars for later use
		local option_target_path_backup="$CONF_TARGET_PATH"
		CONF_TARGET_PATH="$tmpdir"
	else
		# Target is a dir, check if it already exists
		if [ -e "$CONF_TARGET_PATH" ] ; then
			# run some additional checks
			[ -z "$CONF_TARGET_OVERWRITE" ] && {
				msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists. Not instructed to overwrite. Aborting!"
				return 1
			}
			[ ! -d "$CONF_TARGET_PATH" ] && {
				msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists but is not a directory. Don't know what you want me to do in this case, aborting!"
				return 1
			}
			[ ! -w "$CONF_TARGET_PATH" ] && {
				msg_error "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" exists but is not writable, aborting!"
				return 1
			}
		else
			# check if the parent's target directory is writable
			msg_debug "[JOB-${jobid}] Target \"$CONF_TARGET_PATH\" does not exist. Checking if the targets parent dir \"$option_target_path_parentdir\" is writable."
			if [ ! -w "$option_target_path_parentdir" ] ; then
				msg_error "[JOB-${jobid}] Targets parent dir \"$option_target_path_parentdir\" is not writable, aborting!"
				return 1
			fi

			# create target directory
			mkdir "$CONF_TARGET_PATH" > /dev/null 2>&1 || {
				msg_error "[JOB-${jobid}] Could not create directory \"$CONF_TARGET_PATH\", aborting!"
				return 1
			}
		fi
	fi

	# prepare command line, we need to do some fancy expansion in case some 
	# arguments are not given
	local mysqlhotcopy_run=$(echo \
		$CONF_MYSQLHOTCOPY \
		${CONF_DB_SOCKET:+--socket=${CONF_DB_SOCKET}} \
		${CONF_DB_HOST:+--host=${CONF_DB_HOST}} \
		${CONF_DB_PORT:+--port=${CONF_DB_PORT}} \
		${CONF_DB_USER:+--user=${CONF_DB_USER}} \
		${CONF_DB_PASSWORD:+--password=${CONF_DB_PASSWORD}} \
		${CONF_DB_NAMES:---regexp='.*'} \
		${CONF_TARGET_OVERWRITE:+--addtodest} \
		$CONF_MYSQLHOTCOPY_ARGS \
		$CONF_TARGET_PATH \
	)

	# Just do it...
	msg_info "[JOB-${jobid}] Running mysqlhotcopy, cmdline is: \"$mysqlhotcopy_run\"."
	# XXX: this thing really needs to be done like this or else the result value is eaten away by intermediate command(s)
	local mysqlhotcopy_output mysqlhotcopy_retval
	if [ -z "$CONF_DRYRUN" ] ; then
		mysqlhotcopy_output=$(eval ${mysqlhotcopy_run} 2>&1)
		mysqlhotcopy_retval=$?
	else
		mysqlhotcopy_output=""
		mysqlhotcopy_retval=0
	fi

	# check for injuries. 
	if [ $mysqlhotcopy_retval -ne 0 ] ; then
		msg_error "[JOB-${jobid}] Job failed, reason: \"$mysqlhotcopy_output\"."

		# remove tmpdir if we are in gzip mode
		[ -n "$CONF_TARGET_GZIP" ] && {
			msg_info "[JOB-${jobid}] Removing tempdir \"$tmpdir\"."
			remove_tempdir "$tmpdir" || {
				msg_error "[JOB-${jobid}] Could not remove tempdir \"$tmpdir\"."
				return 1
			}
		}
		return 1
	fi

	# Compress the output if required
	[ -n "$CONF_TARGET_GZIP" ] && {
		# switch variables back and tar it
		CONF_TARGET_PATH="$option_target_path_backup"
		local tar_run tar_retval tar_output
		tar_run=$(echo \
			tar -czf \
			"$CONF_TARGET_PATH" \
			-C "$tmpdir" \
			.
		)
		msg_info "[JOB-${jobid}] invoking tar: \"$tar_run\"."
		
		# go for it..
		if [ -z "$CONF_DRYRUN" ] ; then
			tar_output=$(eval ${tar_run} 2>&1)
			tar_retval=$?
		else
			tar_output=""
			tar_retval=0
		fi

		# remove tmpdir
		msg_debug "[JOB-${jobid}] removing \"$tmpdir\"."
		remove_tempdir "$tmpdir" || {
			msg_error "[JOB-${jobid}] Could not remove tempdir \"$tmpdir\"."
			return 1
		}

		# check 
		if [ $tar_retval -ne 0 ] ; then
			msg_error "[JOB-${jobid} tar failed."
			return 1
		fi
	}

	# everything went ok
	msg_info "[JOB-${jobid}] Job completed successfully."
	return 0
}

mysqlhotcopy_rsync() {
	local jobid=$RANDOM
	msg_info "[JOB-${jobid}] Starting remote mysqlhotcopy job"

	# We should behave differently when doing a gzipped job and doing a normal job.
	# honor output filename modifiers
	CONF_TARGET_PATH="${CONF_TARGET_PATH}${CONF_TARGET_TIMESTAMP:+$(date "+%Y%m%d-%H%M%S")}${CONF_TARGET_SUFFIX}"
	# reset the filename modifiers
	CONF_TARGET_TIMESTAMP=""
	CONF_TARGET_SUFFIX=""

	# Rsync gets invoked differently, tempfiles get created instead of tempdirs and
	# so on. It's ugly and too long but this probably the only way to get it right.
	if [ -n "$CONF_TARGET_GZIP" ] ; then
		# We are doing a gzipped job. Figure up a tempfile
		msg_debug "[JOB-${jobid}] Making up a tempfile"
		local tmpfile
		tmpfile=$(create_tempfile)
		if [ $? -ne 0 ] ; then
			msg_error "[JOB-${jobid}] Could not create tempfile, aborting."
			return 1
		else
			msg_debug "[JOB-${jobid}] Tempfile is: \"$tmpfile\"."
		fi

		# switch variables to fool mysqlhotcopy_local, set overwrite to on, change target path to local
		# tempdir
		local switch_target_overwrite_backup=$CONF_TARGET_OVERWRITE
		CONF_TARGET_OVERWRITE="yes"
		local option_target_path_backup=$CONF_TARGET_PATH
		CONF_TARGET_PATH="$tmpfile"

		# attempt local mysqlhotcopy job
		msg_debug "[JOB-${jobid}] Attempting local mysqlhotcopy job."
		mysqlhotcopy_local || {
			msg_error "[JOB-${jobid}] Remote mysqldump job failed because local mysqldump job failed."
			remove_tempfile "$tmpfile"
			return 1
		}

		# restore vars
		CONF_TARGET_PATH=$option_target_path_backup
		CONF_TARGET_OVERWRITE=$option_target_overwrite_backup

		# prepare command line, we need to do some fancy expansion in case some 
		# arguments are not given
		local rsync_run
		case "$CONF_TARGET_TYPE" in
		rsync)
			rsync_run=$(echo \
				$CONF_RSYNC \
				$CONF_RSYNC_ARGS \
				"-a" \
				"$tmpfile" \
				"${CONF_TARGET_RSYNC_USER:+${CONF_TARGET_RSYNC_USER}@}${CONF_TARGET_RSYNC_HOST}:${CONF_TARGET_PATH}"
			)
			;;
		rsync-server)
			rsync_run=$(echo \
				$CONF_RSYNC \
				$CONF_RSYNC_ARGS \
				"-a" \
				"$tmpfile" \
				"${CONF_TARGET_RSYNC_USER:+${CONF_TARGET_RSYNC_USER}@}${CONF_TARGET_RSYNC_HOST}::${CONF_TARGET_PATH}"
			)
			;;
		*)
			msg_error "[JOB-${jobid}] Don't know how to handle rsync target \"${CONF_TARGET_TYPE}\", aborting."
			remove_tempfile "$tmpfile"
			return 1
			;;
		esac

		# Just do it...
		msg_info "[JOB-${jobid}] rsyncing to remote location: \"${rsync_run}\"."
		# XXX: this thing really needs to be done like this or else the result value is eaten away by intermediate command(s)
		local rsync_output rsync_retval
		if [ -z "$CONF_DRYRUN" ] ; then
			rsync_output=$(export RSYNC_PASSWORD="$CONF_TARGET_RSYNC_PASSWORD" ; eval ${rsync_run} 2>&1)
			rsync_retval=$?
		else
			rsync_output=""
			rsync_retval=0
		fi

		# remove tempfile and check for injuries
		remove_tempfile "$tmpfile"
		if [ $rsync_retval -ne 0 ] ; then
			msg_error "[JOB-${jobid}] rsync failed, exit status \"$rsync_retval\", reason: \"$rsync_output\"."
			msg_error "[JOB-${jobid}] Job failed."
			return 1
		else
			msg_info "[JOB-${jobid}] Remote mysqlhotcopy job completed successfully."
			return 0
		fi

	else
		# We are doing a normal job. Figure up a tempdir.
		msg_debug "[JOB-${jobid}] Making up a tempdir"
		local tmpdir
		tmpdir=$(create_tempdir)
		if [ $? -ne 0 ] ; then
			msg_error "[JOB-${jobid}] Could not create tempdir, aborting."
			return 1
		else
			msg_debug "[JOB-${jobid}] Tempdir is: \"$tmpdir\"."
		fi

		# switch variables to fool mysqlhotcopy_local, set overwrite to on, change target path to local
		# tempdir
		local switch_target_overwrite_backup=$CONF_TARGET_OVERWRITE
		CONF_TARGET_OVERWRITE="yes"
		local option_target_path_backup=$CONF_TARGET_PATH
		CONF_TARGET_PATH="$tmpdir"

		# attempt local mysqlhotcopy job
		msg_debug "[JOB-${jobid}] Attempting local mysqlhotcopy job."
		mysqlhotcopy_local || {
			msg_error "[JOB-${jobid}] Remote mysqldump job failed because local mysqldump job failed."
			remove_tempdir "$tmpdir"
			return 1
		}

		# restore vars
		CONF_TARGET_PATH=$option_target_path_backup
		CONF_TARGET_OVERWRITE=$option_target_overwrite_backup

		# prepare command line, we need to do some fancy expansion in case some 
		# arguments are not given
		local rsync_run
		case "$CONF_TARGET_TYPE" in
		rsync)
			rsync_run=$(echo \
				$CONF_RSYNC \
				$CONF_RSYNC_ARGS \
				"-ar" \
				"${tmpdir}/" \
				"${CONF_TARGET_RSYNC_USER:+${CONF_TARGET_RSYNC_USER}@}${CONF_TARGET_RSYNC_HOST}:${CONF_TARGET_PATH}"
			)
			;;
		rsync-server)
			rsync_run=$(echo \
				$CONF_RSYNC \
				$CONF_RSYNC_ARGS \
				"-ar" \
				"${tmpdir}/" \
				"${CONF_TARGET_RSYNC_USER:+${CONF_TARGET_RSYNC_USER}@}${CONF_TARGET_RSYNC_HOST}::${CONF_TARGET_PATH}"
			)
			;;
		*)
			msg_error "[JOB-${jobid}] Don't know how to handle rsync target \"${CONF_TARGET_TYPE}\", aborting."
			remove_tempdir "$tmpdir"
			return 1
			;;
		esac

		# Just do it...
		msg_info "[JOB-${jobid}] rsyncing to remote location: \"${rsync_run}\"."
		# XXX: this thing really needs to be done like this or else the result value is eaten away by intermediate command(s)
		local rsync_output rsync_retval
		if [ -z "$CONF_DRYRUN" ] ; then
			rsync_output=$(export RSYNC_PASSWORD="$CONF_TARGET_RSYNC_PASSWORD" ; eval ${rsync_run} 2>&1)
			rsync_retval=$?
		else
			rsync_output=""
			rsync_retval=0
		fi

		# remove tempfile and check for injuries
		remove_tempdir "$tmpdir"
		if [ $rsync_retval -ne 0 ] ; then
			msg_error "[JOB-${jobid}] rsync failed, exit status \"$rsync_retval\", reason: \"$rsync_output\"."
			msg_error "[JOB-${jobid}] Job failed."
			return 1
		else
			msg_info "[JOB-${jobid}] Remote mysqlhotcopy job completed successfully."
			return 0
		fi
	fi
}

#####################################################################
#                          MAIN                                     #
#####################################################################
[ -n "$CONF_DRYRUN" ] && {
	msg_warn "Dryrun is in effect, not doing anything tricky."
}

case $CONF_DB_METHOD in
mysqldump)
	case $CONF_TARGET_TYPE in
	local)
		mysqldump_local
		exit $?
		;;
	rsync|rsync-server)
		mysqldump_rsync
		exit $?
		;;
	*)
		msg_error "Don't know how to handle database method \"$CONF_DB_METHOD\" with target \"$CONF_TARGET_TYPE\", aborting."
		exit 1
		;;
	esac
	;;
mysqlhotcopy)
	case $CONF_TARGET_TYPE in
	local)
		mysqlhotcopy_local
		exit $?
		;;
	rsync|rsync-server)
		mysqlhotcopy_rsync
		exit 1
		;;
	*)
		msg_error "Don't know how to handle database method \"$CONF_DB_METHOD\" with target \"$CONF_TARGET_TYPE\", aborting."
		exit 1
		;;
	esac
	;;
*)
	msg_error "Don't know how to handle database method \"$CONF_DB_METHOD\" at all, aborting."
	exit 1
	;;
esac
