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
_TEMPLATE_VERSION="trunk"
_TEMPLATE_BASENAME="template"

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################
template_version() {
	echo $_TEMPLATE_VERSION
}

template_init() {
	return 0
}

template_process_placeholder() {
	local template="$1"
	local pname="$2"
	local pvalue="$3"
	[ -z "$pname" -o -z "$template" ] && return 1

	msg_debug "Processing placeholder: pname='$pname', pvalue='$pvalue'"
	local resolved="${template//$pname/$pvalue}"	
	echo "$resolved"
	return 0
}

template_process() {
	local template_file="$1"

	# check for template presence and read it
	[ ! -f "$template_file" -o ! -r "$template_file" ] && {
		msg_debug "Cannot read template file '$template_file'."
		return 1
	}
	msg_debug "Processing template file: '$template_file' with placeholder keys '${!TEMPLATE_PLACEHOLDERS[*]}' and values '${TEMPLATE_PLACEHOLDERS[*]}'."
	local template
	template="$(cat $template_file)"

	# process user-defined placeholders, if there are any
	if [ -n "${!TEMPLATE_PLACEHOLDERS[*]}" ] ; then 
		local pname pvalue
		local peval_errors=0
		for pname in ${!TEMPLATE_PLACEHOLDERS[*]} ; do
			pvalue="${TEMPLATE_PLACEHOLDERS[$pname]}"
			template="$(template_process_placeholder "$template" "$pname" "$pvalue")"
		done
	else
		msg_debug "No placeholders defined."
	fi

	# create tempfile and write the processed template into it
	local tmpfile="$(tempfile_create $_TEMPLATE_BASENAME)"
	[ $? -gt 0 ] && {
		msg_debug "Could not create tempfile."
		return 1
	}
	echo "$template" > $tmpfile

	# print out the temp filename and exit successfuly
	echo "$tmpfile"
	return 0
}
