#!/bin/bash

# Bash functions make plugin
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
#                      GLOBAL PLUGIN VARIABLES                      #
#####################################################################

_MAKE_VERSION="0.10";
_MAKE_CMD=""
_MAKE_OPT=""

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################

# returns version of this plugin
make_version() {
	echo "${_MAKE_VERSION}"
}

make_init() {
	_MAKE_CMD=$(which make 2>/dev/null)
	msg_debug "Discovered make binary: ${_MAKE_CMD}"
}

# make_set_opt()       :: Sets additional make command line options
#
# Arguments:
# $1, ...       (string, "")    :: One or more additional command line options
#
# Returns: 0
make_set_opt() {
        while [ ! -z "${1}" ]; do
                if [ -z "${_MAKE_OPT}" ]; then
                        _MAKE_OPT="${1}"
                else
                        _MAKE_OPT="${_MAKE_OPT} ${1}"
                fi
                shift
        done
        msg_debug "Make command line options set to: ${_MAKE_OPT}"
        return 0
}

# make_get_opt()       :: Prints currently set make additional command line options
#
# Arguments:
#
# Returns: 0
make_get_opt() {
        echo "${_MAKE_OPT}"
        return 0
}

# make_clear_opt()     :: Clears make command line options...
#
# Arguments:
#
# Returns: 0
make_clear_opt() {
        msg_debug "Clearing make command line options."
        _MAKE_OPT=""
        return 0        
}

# make_cmd()	:: Runs make command in specified directory
#
# Arguments:
# $1		: (string, "") Directory in which to start make
#
# Returns: 0 on success, otherwise 1
make_cmd() {
	local dir="${1}"
	if [ -z "${dir}" ]; then
		error_set "Invalid/unspecified directory."
		return 1
	fi

	# check for make binary
	if [ ! -f "${_MAKE_CMD}" -o ! -x "${_MAKE_CMD}" ]; then
		error_set "Invalid make binary: '${_MAKE_CMD}'"
		return 1
	fi

	shift
	local cwd=$(pwd)
	msg_debug "Trying to enter directory: ${dir}"
	if ! cd "${dir}"; then
		error_set "Unable to enter directory ${dir}"
		return 1
	fi
	msg_verbose "Running command: ${_MAKE_CMD} ${_MAKE_OPT} $@"
	${_MAKE_CMD} ${_MAKE_OPT} $@
	local rv=$?
	if [ "${rv}" != "0" ]; then
		error_set "Make exited with non-zero exit status: ${rv}"
	fi
	msg_debug "Returnig to directory: ${cwd}"
	if ! cd "${cwd}"; then
		error_set "Unable to enter directory: ${cwd}"
		return 1
	fi

	return $rv
}

# EOF
