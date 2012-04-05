#!/bin/bash

# Bash functions example plugin
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

_EXAMPLE_VAR="njami"

example_version() {
	echo "0.10"
}

example_init() {
	msg_debug "This is plugin example init function!"
	msg_verbose "This is verbose message."
	msg_info "This is info message."
	msg_warn "This is warning message."
	msg_err "This is error message."
	_EXAMPLE_VAR="${_EXAMPLE_VAR}_${RANDOM}"
	return 0;
}

example_testfunc() {
	msg_info "This is example_testfunc() function, using global variable ${TERM_BOLD}\${_EXAMPLE_VAR}${TERM_RESET}: ${_EXAMPLE_VAR}" 
}

# EOF
