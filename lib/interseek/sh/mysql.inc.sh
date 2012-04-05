#!/bin/bash

# Bash functions mysql plugin
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

_MYSQL_VERSION="0.10";
_MYSQL_BIN=""
_MYSQL_DUMP=""

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################

# returns version of this plugin
mysql_version() {
	echo "${_MYSQL_VERSION}"
}

# initializes plugin
mysql_init() {
	PATH="${PATH}:/export/software/mysql/bin"
	PATH="${PATH}:/export/software/mysql/sbin"
	msg_debug "Looking for mysql binaries in \$PATH."
	_MYSQL_BIN=$(which mysql 2>/dev/null)
	_MYSQL_DUMP=$(which mysqldump 2>/dev/null)
	msg_debug "Binary mysql(1): ${_MYSQL_BIN}"
	msg_debug "Binary mysqldump(8): ${_MYSQL_DUMP}."
	
	if [ -z "${_MYSQL_BIN}" -o -z "${_MYSQL_DUMP}" ]; then
		error_set "Unable to find mysql binaries in \$PATH."
		return 1
	fi

	return 0
}

# Executes SQL query
#
# EXAMPLE:
#	echo "SELECT * FROM table_name" | mysql_query "host" 3306 "username" "secret" "database_name"
#
mysql_query() {
	local host="${1}"
	local port="${2}"
	local user="${3}"
	local pass="${4}"
	local db="${5}"
	
	if [ -z "${_MYSQL_BIN}" -o ! -x "${_MYSQL_BIN}" ]; then
		error_set "Invalid mysql binary: ${_MYSQL_BIN}"
		return 1
	fi
	if [ -z "${db}" ]; then
		error_set "Invalid database name"
		return 1
	fi
	
	msg_debug "Executing SQL on ${host}:${port} as user ${user} on database ${db}"

	"${_MYSQL_BIN}" -h "${host}" -P "${port}" \
		-u "${user}" -p"${pass}" "${db}" -B --skip-pager -s

	local rv=$?
	msg_debug "Mysql client exited with code: $rv"
	
	return $rv
}

# EOF
