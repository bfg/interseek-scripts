#!/bin/bash

# Bash functions directory synchronization plugin
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

dirsync_version() {
	echo "0.11"
}

dirsync_init() {
	plugin_load "archive" 1
	return 0;
}

dirsync_run() {
	local var="${1}"
	local dir="${2}"

	if [ -z "${dir}" -o -z "${var}" ]; then
		error_set "Usage: dirsync_run <dir> <conf_var_name>"
		return 1
	fi

	local conf_value
	declare -a conf_value=$(var_as_str "${var}")
	if [ -z "${conf_value}" ]; then
		msg_warn "Empty dirsync jobs variable '${TERM_BOLD}${var}${TERM_RESET}'; nothing to do; returning success anyway."
		return 0
	fi

	local i=0
	while [ -n "${conf_value[${i}]}" ]; do
		local chunk="${conf_value[${i}]}"
		i=$((i + 1))
		local src=`echo "$chunk" | awk -F\| '{print $1}'`
		local dst=`echo "$chunk" | awk -F\| '{print $2}'`
		local flags=`echo "$chunk" | awk -F\| '{print $3}'`
		local type=$(_dirsync_type "$src")
		
		# sanitize destination
		dst=`_dirsync_sanitize "${dir}/${dst}"`
		
		# run sync function...
		msg_info "Syncing ${TERM_YELLOW}${src}${TERM_RESET} to ${TERM_LGREEN}${dst}${TERM_RESET} using ${TERM_BOLD}${type}${TERM_RESET}."
		_dirsync_${type} "$src" "$dst" "$flags" || return 1
	done

	return 0
}

_dirsync_sanitize() {
	echo "$@" | sed -e 's/\.\.//g' | sed -e 's/\/\//\//g'
}

_dirsync_type() {
	if echo "$1" | egrep '^http(s)?://.+/' >/dev/null 2>&1; then
		echo "www"
	elif echo "$1" | egrep '^ftp(s)?://.+/' >/dev/null 2>&1; then
		echo "www"
	elif echo "$1" | egrep '^\/.+' >/dev/null 2>&1; then
		echo "fs"
	else
		echo "unknown"
	fi
}

_dirsync_unknown() {
	local url="$1"
	local dst="$2"
	die "Unknow directory synchronization source: \"$url\""
}

_dirsync_www() {
	local url="$1"
	local dst="$2"
	local flags="$3"
	
	local archive=$(parse_flags "$flags" "archive")
	local suffix=$(_dirsync_suffix_get "$src")
	local archive_suffix=$(parse_flags "$flags" "archive_suffix")
	local unpack_flags=$(parse_flags "$flags" "unpack_flags")
	
	# create destination directory...
	if ! mkdir -p "$dst"; then
		errror_set "Unable to create directory '$dst'."
		return 1
	fi

	# download file to temporary location
	local f=$(mktemp 2>/dev/null)
	if [  -z "$f" ]; then
		error_set "Unable to create unique tmp file."
		return 1
	fi
	msg_info "    Fetching files from '${TERM_YELLOW}$url${TERM_RESET}' to '${TERM_YELLOW}$dst${TERM_RESET}'."
	if ! wget --no-check-certificate -qO "$f" "$url"; then
		error_set "Unable to fetch URL '$url'."
		return 1
	fi

	if [ ! -z "${suffix}" ]; then
		if ! mv "${f}" "${f}.${suffix}"; then
			error_set "Unable to move 1 '$f' => '$f.${suffix}'."
			return 1
		fi
		f="${f}.${suffix}"
	fi

	# ok, now we have a file... well unpack or just copy it to $dst...
	if [ "$archive" = "1" ]; then
		# rename file if we have archive suffix...
		if [ ! -z "$archive_suffix" ]; then
			if ! mv "${f}" "${f}.${archive_suffix}"; then
				error_set "Unable to move  2 '$f' => '$f.${archive_suffix}'."
				rm -f "${f}" >/dev/null 2>&1
				return 1
			fi
			f="${f}.${archive_suffix}"
		fi

		archive_unpack "$f" "$dst" "$unpack_flags" || return 1
		rm -f "${f}" >/dev/null 2>&1
	else
		# just copy files: use tar for directories
		# and cp for files
		local method="tar"
		if [ ! -d "${f}" ]; then
			# copy files using tar
			( cd "${f}" && tar -cpf - * | tar -xpf - -C "$dst" )
		else
			method="cp"
			cp -fa "${f}" "${dst}/"$(basename "${url}")
		fi

		# check for injuries
		local rv=$?
		if [ "$rv" != "0" ]; then
			error_set "Error copying files using ${method}: exit code: $rv"
			return 1
		fi
	fi

	rm -f "${f}" >/dev/null 2>&1
	return 0
}

_dirsync_fs() {
	local src="$1"
	local dst="$2"
	local flags="$3"

	msg_info "    Copying files from '${TERM_YELLOW}$src${TERM_RESET}' to '${TERM_YELLOW}$dst${TERM_RESET}'."

	# create destination if necessary
	if ! mkdir -p "$dst"; then
		error_set "Unable to create directory '$dst'."
	fi
	
	local archive=$(parse_flags "$flags" "archive")
	local unpack_flags=$(parse_flags "$flags" "unpack_flags")

	if [ "$archive" = "1" ]; then
		test ! -f "$src" && error_set "Not an archive file '$src'." && return 1
		archive_unpack "$src" "$dst" "$unpack_flags" || return 1
	else
		test ! -d "$src" && error_set "Not a directory: '$src'." && return 1
		# check if there is anything in repository...
		local num_files=$(ls "${src}" 2>/dev/null | wc -l)
		if [ "$num_files" = "0" ]; then
			msg_warn "    Empty repository '$src', ignoring returning success."
			return 0
		fi
		
		# copy files using tar
		( cd "$src" && tar -cpf - * | tar -xpf - -C "$dst" )
		local rv=$?
		if [ "$rv" != "0" ]; then
			error_set "Error copying files; exit code: $rv"
			return 1
		fi
	fi
	
	return 0
}

_dirsync_suffix_get() {
	# This is sooo ugly...
	local x=$(basename "$1" | perl -e '$x = <STDIN>; chomp $x; if ($x =~ m/(tar\.)?([^\.]+)$/i) { print "$1$2\n"; }')
	if [ "${x}" != "${1}" ]; then
		echo "$x"
	else
		echo ""
	fi
}

# EOF
