#!/bin/bash

# Bash functions java plugin
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

_JAVA_JVM=""
_JAVA_JVM_DEFAULT_LOC="/export/software/java/jvm /usr"

java_version() {
	echo "0.11"
}

java_init() {
	local d=""
	for d in "" ${_JAVA_JVM_DEFAULT_LOC}; do
		_JAVA_JVM=$(java_jvm_get "${d}")
		if [ ! -z "${_JAVA_JVM}" ]; then
			break
		fi
	done
	msg_debug "Default java jvm: ${_JAVA_JVM}"
	return 0;
}

java_classpath_get() {
	msg_verbose "Searching for java archives and classes in: $@"
	local cp=""
	local dir=""
	for dir in "$@"; do
		test -z "${dir}" && continue
		test -e "${dir}" || continue
		
		if [ -f "${dir}" ]; then
			msg_debug "Adding file to classpath: ${dir}"
			cp="${cp}:${dir}"
		else
			# is this maybe a symlink?
			if [ -L "${dir}" ]; then
				msg_debug "Resolving symlink: ${dir}"
				dir=$(readlink -e -q "${dir}")
				msg_debug "Resolved symlink: ${dir}"
			fi

			# must be readable directory
			test -z "${dir}" -o ! -d "${dir}" -o ! -r "${dir}" && continue
			msg_verbose "Searching for java archives in directory: ${dir}"

			local f=""
			# find JARs
			for f in $(find "${dir}" -type f -name '*.jar'); do
				cp="${cp}:${f}"
			done
	
			# find classes
			local x=$(find "${dir}" -type f -name '*.class' 2>/dev/null)
			if [ ! -z "${x}" ]; then
				cp="${cp}:${dir}"
			fi
			
			# find props...
			local x=$(find "${dir}" -type f -name '*.properties' 2>/dev/null)
			if [ ! -z "${x}" ]; then
				cp="${cp}:${dir}"
			fi
		fi
	done
	msg_debug "Constructed classpath: ${cp}"
	echo "${cp}"

	return 0
}

# Prints full path to java binary
#
# ARGUMENTS:
#	$1 (string, "", optional) :: Path to java home
#
# RETURNS:
#	0 on success, otherwise 1
java_jvm_get() {
	local dir="$1"
	test -z "${dir}" && dir="${JAVA_HOME}"
	if [ -z "${dir}" -o ! -d "${dir}" ]; then
		error_set "Invalid java_home dir: '${dir}'"
		return 1
	fi

	local bin=""
	msg_debug "Searching for java vm in: ${dir}"
	for bin in java{,.exe} jre{,.exe}; do
		local b="${dir}/bin/${bin}";
		msg_debug "Checking for: ${b}"
		if [ -f "${b}" -a -x "${b}" ]; then
			msg_verbose "JVM found: ${b}"
			echo "${b}"
			return 0
		fi
	done

	error_set "JVM not found in: $dir"
	return 1
}

# Prints full path to JAVA_HOME
#
# RETURNS:
#	0 on success, otherwise 1
java_home_get() {
	local jvm=$(java_jvm_get)
	if [ -z "${jvm}" ]; then
		echo ""
		return 1
	fi
	local home=$(dirname "${jvm}")
	home=$(dirname "${home}")
	echo "${home}"
	return 0
}

# java_run "${JAVA_CLASS}" "${JAVA_FLAGS}" "${JAVA_LIBDIR}" "${JAVA_HOME}" $@
java_run() {
	local java_class="$1"
	shift
	local java_flags="$1"
	shift
	local java_libdir="$1"
	shift
	local java_home="$1"
	shift
	
	test -z "${java_home}" && java_home="/usr"

	# backup classpath variable
	local cp_backup="${CLASSPATH}"
	
	# check classpath
	if [ ! -z "${java_libdir}" ]; then
		local cp=$(java_classpath_get "${java_libdir}")
		test -z "${cp}" && error_set "Nothing found in JAVA_LIBDIR '${java_libdir}'." && return 1
		CLASSPATH="${cp}"
		export CLASSPATH
	fi

	local jvm=$(java_jvm_get "${java_home}")
	test -z "${jvm}" && error_set "Unable to find JVM in '${java_home}'" && return 1
	
	# build running string
	local run="${jvm} ${java_flags} ${java_class}"

	# run the bastard
	msg_verbose "Running: ${run} $@"

	eval ${run} $@

	local rv=$?
	if [ "${rv}" != "0" ]; then
		error_set "JVM exited with non-zero exit code $rv."
	fi
	return $rv
}

# java_run_simple "{java_class|java_jar}" "java_flags" $@
java_run_simple() {
	local java_class="${1}"
	shift
	local java_flags="${1}"
	shift
	
	local run="${_JAVA_JVM}"
	
	test ! -z "${java_flags}" && run="${run} ${java_flags}"
	
	if echo "${java_class}" | egrep -qi '\.jar$'; then
		run="${run} -jar ${java_class}"
	else
		run="${run} ${java_class}"
	fi

	msg_verbose "Running: ${run} $@"
	${run} $@

	local rv=$?
	if [ "${rv}" != "0" ]; then
		error_set "JVM exited with non-zero exit code $rv."
	fi
	return $rv
}

# EOF
