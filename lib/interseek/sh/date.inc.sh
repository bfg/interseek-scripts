#!/bin/bash

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

_DATE_VERSION="trunk"

date_version() {
	echo "${_DATE_VERSION}"
}

date_init() {
	return 0;
}

date_valid() {
	local d="$1"
	[ -z "$d" ] && return 1
	date --date="$d" > /dev/null 2>&1 
	return $?
}

date_today() {
	echo "$(date +%Y%m%d)"
}

date_yesterday() {
	echo "$(date --date=yesterday +%Y%m%d)"
}

date_interval() {
	local from=$1
	date_valid "$from" || return 1

	local to=$2
	date_valid "$to" || return 1
	
	local cur="$from"
	while [ "$cur" -le "$to" ]; do
		echo -n "${cur} "
		cur=$(date --date "$cur + 1 day" +%Y%m%d)
	done
	
	return 0
}

date_day() {
	local date=$1
	date_valid "$date" || return 1
	echo ${date:6:2}
	return 0
}

date_month() {
	local date=$1
	date_valid "$date" || return 1
	echo ${date:4:2}
	return 0
}

date_year() {
	local date=$1
	date_valid "$date" || return 1
	echo ${date:0:4}
	return 0
}
