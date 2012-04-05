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
PROG_NAME="brun.sh"
PROG_VERSION="trunk"

# this should get set, otherwise we wont receive the SIGCHLD signal when the
# child exits.
set -m

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

###############################################################################
#			  CMDLINE PLUGIN CONFIGURATION
###############################################################################
#
# command line arguments
#
ARGL_TIME_DELAY="delay:"
CONF_TIME_DELAY=""
HELP_TIME_DELAY="Delay execution this much seconds, default: none. Can be an integer value or a comma-separated list of *two* integer values: delay-min,delay-max, in which case a random number from this interval is chosen as the delay-value."
VAL_TIME_DELAY="1"

ARGL_TIME_EXEC="timeout:"
CONF_TIME_EXEC=""
HELP_TIME_EXEC="Maximum execution time, in seconds, default: none"
VAL_TIME_EXEC="1"

ARG_DRYRUN="n"
ARGL_DRYRUN="dry-run"
CONF_DRYRUN=""
HELP_DRYRUN="Fake execution, just report what would be done."

ARG_PIDFILE="p:"
ARGL_PIDFILE="pidfile:"
CONF_PIDFILE=""
HELP_PIDFILE="Pidfile to read/create."

ARG_TIME_SLEEP="s:"
ARGL_TIME_SLEEP="sleep:"
CONF_TIME_SLEEP="1"
HELP_TIME_SLEEP="Time to sleep in an endless loop, default: $CONF_TIME_SLEEP"
VAL_TIME_SLEEP="1"

CONF_TIMESTAMP_FORMAT="+%Y-%m-%d %H:%M:%S"

#
# validator functions
#
validate_TIME_DELAY() {
	[ -z "$CONF_TIME_DELAY" ] && return 0

	# check if it contains what we expect
	echo "$CONF_TIME_DELAY" | grep -P '^\d+(,\d+)?$' 2>&1 > /dev/null || {
		msg_error "Invalid delay string: '$CONF_TIME_DELAY'."
		return 1
	}

	# parse the values
	set ${CONF_TIME_DELAY//,/ }
	CONF_TIME_DELAY_MIN="$1"
	CONF_TIME_DELAY_MAX="$2"

	# we are done if maximum time delay is not set
	[ -z "$CONF_TIME_DELAY_MAX" ] && {
		CONF_TIME_DELAY="$CONF_TIME_DELAY_MIN"
		msg_debug "Assigned CONF_TIME_DELAY='$CONF_TIME_DELAY'"
		return 0
	}

	# check time interval for validity
	[ "$CONF_TIME_DELAY_MAX" -le "$CONF_TIME_DELAY_MIN" ] && {
		msg_error "Invalid delay string: '$CONF_TIME_DELAY', hint: TIME_DELAY_MAX <= TIME_DELAY_MIN"
		return 1
	}

	# do some math to obtain a proper value. First, check if bc is installed.
	which bc 2>&1 > /dev/null || {
		msg_error "External binary 'bc' not installed, aborting."
		return 1
	}
	local interval=$(( $CONF_TIME_DELAY_MAX - $CONF_TIME_DELAY_MIN ))
	CONF_TIME_DELAY=$( echo "scale=3; $CONF_TIME_DELAY_MIN + $interval * ($RANDOM / 32768) " | bc )
	return 0
}

validate_TIME_EXEC() {
	[ -z "$CONF_TIME_EXEC" ] && return 0

	# check if it contains what we expect
	echo "$CONF_TIME_EXEC" | grep -P '^\d+$' 2>&1 > /dev/null || {
		msg_error "Invalid execution time: '$CONF_TIME_EXEC'."
		return 1
	}

	return 0
}

validate_TIME_SLEEP() {
	[ -z "$CONF_TIME_SLEEP" ] && {
		msg_error "No sleep time given." 
		return 1
	}

	# check if it contains what we expect
	echo "$CONF_TIME_SLEEP" | grep -P '^\d+$' 2>&1 > /dev/null || {
		msg_error "Invalid sleep time: '$CONF_TIME_SLEEP'."
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
This program runs a specified binary in the background, with some additional
options.

Usage: 
  brun.sh [options] -- binary binary-args

  Execution handling:
EOF
	cmdline_helpfor TIME_DELAY
	cmdline_helpfor TIME_EXEC
	cmdline_helpfor TIME_SLEEP
	cmdline_helpfor PIDFILE
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
#			     APPLICATION FUNCTIONS
###############################################################################
create_pidfile() {
	local pid="$1"
	[ -z "$pid" ] && {
		msg_debug "No pid given, aborting"
		return 1
	}

	local fn="$2"
	[ -z "fn" ] && {
		msg_debug "No filename given, aborting."
		return 1
	}

	echo "$$" > "$fn"
	return $?
}

remove_pidfile() {
	local fn="$1"
	[ -z "$fn" ] && {
		msg_debug "No filename given, aborting."
		return 1
	}
	[ ! -w "$fn" ] && {
		msg_debug "File '$fn' does not exist or is not writable, cannot remove."
		return 1
	}

	rm "$fn" 2>&1 > /dev/null
	local retval=$?
	[ $retval -ne 0 ] && {
		msg_debug "Could not remove pidfile: '$fn'." 
	}
	return $retval
}

read_pidfile() {
	local fn="$1"
	[ -z "$fn" ] && {
		msg_debug "No pidfile given."
		return 1
	}
	[ ! -r "$fn" ] && {
		msg_debug "No pidfile found: '$CONF_PIDFILE'." 
		return 1
	}
 	local pid=$(cat "$fn") || {
		msg_debug "Could not read pidfile: '$fn'." 
		exit 1
	}
	echo "$pid"
	return 0
}

is_process_running() {
	local pid="$1"
	[ -z "$pid" ] && {
		msg_debug "No pid given."
		exit 1
	}
	local name="$2"

	# match pid
	local out
	out=$(ps -o pid= -o comm= -p $pid) || {
		msg_debug "pid '$pid' is *not* running."
		return 1
	}
	[ -z "$name" ] && {
       		msg_debug "pid '$pid' is running."	
		return 0
	}

	# match pid and process name
	set $out
	local retrieved_pid="$1"
	local retrieved_name="$2"
	if [ "$pid" == "$retrieved_pid" -a "$name" == "$retrieved_name" ] ; then
		msg_debug "pid '$pid' with name '$name' is running"
		return 0
	else
		msg_debug "pid '$pid' with name '$name' is *not* running."
		return 1
	fi
}

terminate() {
	local pid="$1"
	[ -z "$pid" ] && return 1

	# kill the bastard
	is_process_running $pid && {
		kill "$pid" 2>&1 > /dev/null || {
			msg_error "Could not kill pid '$pid'."
			return 1
		}
		sleep 1
		is_process_running $pid && {
			kill "$pid" 2>&1 > /dev/null || {
				msg_error "Could not kill pid '$pid' on second try."
				return 1
			}
			sleep 10
			is_process_running $pid && {
				kill -s KILL "$pid" 2>&1 > /dev/null || {
					msg_error "Could not kill pid '$pid' on third try."
					return 1
				}
				sleep 1
				is_process_running "$pid" && {
					msg_error "pid '$pid' is still alive, even after SIGKILL."
					return 1
				}
				msg_debug "pid '$pid' killed with SIGKILL."
				return 0
			}
			msg_debug "pid '$pid' killed with SIGTERM on second try."
			return 0
		}
		msg_debug "pid '$pid' killed with SIGTERM on first try."
		return 0
	}
	msg_debug "pid '$pid' not running, so not killed."
	return 0
}

cleanup() {
	# remove pidfile
	[ -n "$CONF_PIDFILE" ] && {
		rm "$CONF_PIDFILE" 2>&1 > /dev/null || {
			msg_error "Could not remove pidfile: '$CONF_PIFILE'"
		}
	}

	# some output
	local t_stop=$(date +%s)
	local t_elapsed=$(( $t_stop - $t_start ))
	msg_verbose "Child was alive for ${t_elapsed}s."
	exit 0
}

msg_verbose_ts() {
	msg_verbose [$(date "$CONF_TIMESTAMP_FORMAT")] "$*"
}

msg_debug_ts() {
	msg_debug [$(date "$CONF_TIMESTAMP_FORMAT")] "$*"
}

###############################################################################
#				SIGNAL HANDLERS
###############################################################################
SIGTERM_handler() {
	msg_verbose_ts "SIGTERM caught. Trying to kill child with pid '$pid_child'."
	terminate "$pid_child"
	cleanup
	exit 0
}

SIGCHLD_handler() {
	msg_debug_ts "SIGCHLD caught."
	is_process_running "$pid_child" "$bin_basename" || {
		msg_verbose_ts "Child '$pid_child' has finished." 
		cleanup
		exit 0
	}
}

###############################################################################
#				      MAIN
###############################################################################
# check for dryrun
[ -n "$CONF_DRYRUN" ] && {
	msg_warn "Dryrun is in effect, faking execution."
}

# parse the ARG_UNPARSED stuff to get the binary name and its arguments
[ -z "$ARG_UNPARSED" ] && {
	msg_error "No binary given."
	exit 1
}
set $ARG_UNPARSED
bin="$(which $1)" || {
	msg_error "Cant find binary '$1'"
	exit 1
}
shift
bin_args="$*"
bin_basename=$(basename $bin)

# check for executabilty of the binary
[ ! -x "$bin" ] && {
	msg_error "Cant execute binary '$bin'"
	exit 1
}

# delay execution if we are required to do so
[ -n "$CONF_TIME_DELAY" ] && {
	msg_verbose_ts "Delaying for '$CONF_TIME_DELAY' seconds. "
	sleep $CONF_TIME_DELAY
}

# check for the existence of pidfile. If exists, parse it.
pid_pidfile="$(read_pidfile $CONF_PIDFILE)" && {
	msg_debug "Pidfile '$CONF_PIDFILE' found."
	is_process_running $pid_pidfile $bin_basename && {
		msg_error "Pid '$pid_pidfile' with binary '$bin_basename' is already running, aborting."
		exit 1
	}
}

# run the binary: first some output, then a timer, then install the signal
# handlers and run the binary *immediately* after the handlers have been
# installed, then get the childs pid
if [ -z "$CONF_DRYRUN" ] ; then 
	msg_verbose_ts "Running command: '$ARG_UNPARSED'"
	t_start="$(date +%s)"
	trap SIGTERM_handler SIGTERM
	trap SIGCHLD_handler SIGCHLD
	$ARG_UNPARSED &
	pid_child="$!"
else
	msg_verbose "Would run: '$ARG_UNPARSED'"
	exit 0
fi

# check for child pid
if [ -n "$pid_child" ] ; then
	msg_verbose_ts "Child started with pid $pid_child."
	# write pid to pidfile if so desired
	[ -n "$CONF_PIDFILE" ] && {
		msg_debug "Writing pid '$pid_child' to pidfile '$CONF_PIDFILE'."
		echo "$pid_child" > "$CONF_PIDFILE" || {
			msg_error "Could not write pid '$pid_child' to pidfile '$CONF_PIDFILE', continuing."
		}
	}
else
	msg_error "Could not run: '$ARG_UNPARSED &', aborting."
	exit 1
fi

# go into an endless loop
while true ; do
	# exit if the child has gone away
	is_process_running "$pid_child" "$bin_basename" || {
		msg_verbose_ts "Child '$bin_basename' with pid '$pid_child' has gone away but no SIGCHLD received! Funny. Exiting."
		cleanup
		exit 1
	}

	# check if we are running with an execution timer 
	[ -n "$CONF_TIME_EXEC" ] && {
		# terimante if we reached the timeout
		t="$(date +%s)"
		t_elapsed=$(( $t - $t_start ))
		t_exceeded=$(( $t_elapsed - $CONF_TIME_EXEC ))
		[ $t_elapsed -ge $CONF_TIME_EXEC ] && {
			msg_verbose_ts "Execution timeout of ${CONF_TIME_EXEC}s exceeded by ${t_exceeded}s, terminating pid $pid_child."
			if terminate "$pid_child"  ; then
				cleanup	
			else 
				msg_error "Could not terminate child '$child_pid'."
			fi
		}
	}

	# go to sleep for the configured amount of time
	sleep $CONF_TIME_SLEEP
done

exit 0
