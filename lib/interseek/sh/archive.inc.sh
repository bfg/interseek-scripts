#!/bin/bash

# Bash functions archive manipulation plugin
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

_ARCHIVE_VERSION="0.12"

archive_version() {
	echo "${_ARCHIVE_VERSION}"
}

archive_init() {
	return 0;
}

# archive_create():	Create file archive from specified directory
#
# Arguments:
#	$1		(string, ""): directory containing files
#	$2		(string, ""): ouput filename; archive type will be
#                         recognized by file suffix. Missing directories
#                         are automatically created.
#
# Returns: 0 on success, otherwise 1
archive_create() {
	local src="$1"
	local dst="$2"	
	
	if [ -z "${src}" -o ! -d "${src}" -o ! -r "${src}" ]; then
		error_set "Invalid source directory: '${src}'"
		return 1
	fi

	if [ -z "${dst}" ]; then
		error_set "Invalid archive destination."
		return 1
	fi
	
	# check for parent directory...
	local parent=$(dirname "${dst}")
	if [ ! -e "${parent}" ]; then
		msg_debug "Creating parent directory: ${parent}"
		if ! mkdir "${parent}"; then
			error_set "Unable to create parent directory: '${parent}'"
			return 1
		fi
	fi
	
	local cwd=$(pwd)
	msg_debug "Entering directory: ${src}"
	if ! cd "${src}"; then
		error_set "Unable to enter directory: ${src}"
		return 1
	fi

	local rv=0
	if echo "${dst}" | egrep -qi '\.tar$'; then
		msg_debug "Creating tar archive: ${dst}"
		tar cpf "${dst}" .
		rv=$?
	elif echo "${dst}" | egrep -qi '\.(tar(\.gz|\.Z)|tgz)$'; then
		msg_debug "Creating gzipped tar archive: ${dst}"
		tar czpf "${dst}" .
		rv=$?
	elif echo "${dst}" | egrep -qi '\.(tar\.bz2|tbz)$'; then
		msg_debug "Creating bzipped tar archive: ${dst}"
		tar cjpf "${dst}" .
		rv=$?
	elif echo "${dst}" | egrep -qi '\.(zip|jar)$' ; then
		msg_debug "Creating zip archive: ${dst}"
		zip -ry9q "$dst" .
		rv=$?
	else
		error_set "Don't know how to create archive: '${dst}'"
		return 1
	fi
	
	msg_debug "Returning back to directory: ${src}"
	if ! cd "${cwd}"; then
		error_set "Unable to return back to directory: ${cwd}"
		return 1
	fi

	return $rv
}

# archive_unpack ()	:: unpacks (gzipped|bzipped)? tar/zip archive to specified directory.
#
# Arguments:
#	$1		(string, ""): archive filename
#	$2		(string, ""): destination directory
#   $3      (string, ""): archive-type specific additional unpack flags
#
# Returns: 0 on success, otherwise 1
archive_unpack() {
	local src="$1"
	local dst="$2"
	local flags="$3"
	
	if [ -z "${src}" -o ! -f "${src}" -o ! -r "${src}" ]; then
		error_set "Invalid archive filename: '${src}'"
		return 1
	fi
	if [ -z "${dst}" ]; then
		error_set "Invalid destination directory: '${dst}'"
		return 1
	fi
	
	# try to create destination directory
	if ! mkdir -p "${dst}"; then
		error_set "Unable to create destination directory: '${dst}'"
		return 1
	fi

	local rv
	if echo "$src" | egrep -qi '\.tar$'; then
		msg_debug "Unpacking tar archive: ${src}"
		tar ${flags} -xpf "$src" -C "$dst"
		rv=$?
	elif echo "$src" | egrep -qi '\.(tar(\.gz|\.Z)|tgz)$'; then
		msg_debug "Unpacking gzipped tar archive: ${src}"
		tar ${flags} -zxpf "$src" -C "$dst"
		rv=$?
	elif echo "$src" | egrep -qi '\.(tar\.bz2|tbz)$'; then
		msg_debug "Unpacking bzipped tar archive: ${src}"
		tar ${flags} -jxpf "$src" -C "$dst"
		rv=$?
	elif echo "$src" | egrep -qi '\.(zip|jar|war)$'; then
		msg_debug "Unpacking zip archive: ${src}"
		unzip ${flags} -oqq "$src" -d "$dst"
		rv=$?
	else
		error_set "I don't know how to unpack file: ${src}"
		return 1
	fi
	
	if [ "${rv}" != "0" ]; then
		error_set "Unable to unpack file: '${src}'."
	fi

	return $rv
}

# EOF
