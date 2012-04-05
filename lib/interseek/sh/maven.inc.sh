#!/bin/bash

# Bash functions maven plugin
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

_MAVEN_VERSION="0.10";
_MAVEN_CMD=""
_MAVEN_OPT=""

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################

# returns version of this plugin
maven_version() {
	echo "${_MAVEN_VERSION}"
}

maven_init() {
	_MAVEN_CMD=$(which mvn 2>/dev/null)
	msg_debug "Discovered maven binary: ${_MAVEN_CMD}"
	maven_clear_opt
}

# maven_set_opt()	:: Sets additional maven command line options
#
# Arguments:
# $1, ...	(string, "")	:: One or more additional command line options
#
# Returns: 0
maven_set_opt() {
	while [ ! -z "${1}" ]; do
		if [ -z "${_MAVEN_OPT}" ]; then
			_MAVEN_OPT="${1}"
		else
			_MAVEN_OPT="${_MAVEN_OPT} ${1}"
		fi
		shift
	done
	msg_debug "Maven command line options set to: ${_MAVEN_OPT}"
	return 0
}

# maven_get_opt()	:: Prints currently set maven additional command line options
#
# Arguments:
#
# Returns: 0
maven_get_opt() {
	echo "${_MAVEN_OPT}"
	return 0
}

# maven_clear_opt()	:: Clears maven command line options...
#
# Arguments:
#
# Returns: 0
maven_clear_opt() {
	msg_debug "Clearing maven command line options."
	_MAVEN_OPT=""
	return 0	
}

# maven_cmd()	:: Runs maven command in specified directory
#
# Arguments:
# $1		: (string, "") Directory in which to start maven
# $2,...	: (string, "") One or more maven commands to perform
#
# Returns: 0 on success, otherwise 1
maven_cmd() {
	local dir="${1}"
	if [ -z "${dir}" ]; then
		error_set "Invalid/unspecified directory."
		return 1
	fi

	# check for maven binary
	if [ ! -f "${_MAVEN_CMD}" -o ! -x "${_MAVEN_CMD}" ]; then
		error_set "Invalid maven binary: '${_MAVEN_CMD}'"
		return 1
	fi

	shift
	local cwd=$(pwd)
	msg_debug "Trying to enter directory: ${dir}"
	if ! cd "${dir}"; then
		error_set "Unable to enter directory ${dir}"
		return 1
	fi
	msg_verbose "Running command: ${_MAVEN_CMD} ${_MAVEN_OPT} $@"
	${_MAVEN_CMD} ${_MAVEN_OPT} $@
	local rv=$?
	if [ "${rv}" != "0" ]; then
		error_set "Maven exited with non-zero exit status: ${rv}"
	fi
	msg_debug "Returnig to directory: ${cwd}"
	if ! cd "${cwd}"; then
		error_set "Unable to enter directory: ${cwd}"
		return 1
	fi

	return $rv
}

# maven_deploy_file()	:: deploys specified file in maven repository
#
# Arguments:
#	$1	:	(string, ""): File to deploy
#	$2	:	(string, ""): artifact groupId
#	$3	:	(string, ""): artifactId
#	$4	:	(string, ""): artifact version string
#	$5	:	(string, ""): maven repository id
#	$6	:	(string, ""): maven repository url
#
# Returns: 0 on success, otherwise 1
maven_deploy_file() {
	local file="$1"
	local group_id="$2"
	local artifact_id="$3"
	local artifact_version="$4"
	local repo_id="$5"
	local repo_url="$6"
	
	if [ ! -f "${file}" -o ! -r "${file}" ]; then
		error_set "Invalid deploy file: '${file}'"
		return 1
	fi
	
	if [ -z "${group_id}" ]; then
		error_set "Undefined groupId."
		return 1
	fi

	if [ -z "${artifact_id}" ]; then
		error_set "Undefined artifactId."
		return 1
	fi

	if [ -z "${artifact_version}" ]; then
		error_set "Undefined artifact version."
		return 1
	fi
	artifact_version=$(shell_pattern_resolve "${artifact_version}")

	if [ -z "${repo_id}" ]; then
		error_set "Undefined maven repository id."
		return 1
	fi
	if [ -z "${repo_url}" ]; then
		error_set "Undefined maven repository url"
		return 1
	fi

	local packaging=$(echo "${file}" | perl -pi -e 's/(.+)\.([a-z]+)$/$2/')
	if [ -z "${packaging}" ]; then
		error_set "Unable to determine maven packaging."
		return 1
	fi

	maven_cmd \
		$(dirname "${file}") \
		deploy:deploy-file \
		-Dfile=${file} \
		-DgroupId=${group_id} \
		-DartifactId=${artifact_id} \
		-Dversion=${artifact_version} \
		-Dpackaging=${packaging} \
		-DrepositoryId=${repo_id} \
		-Durl=${repo_url} \
		-DgeneratePom=true
	
	local rv=$?
	if [ "${rv}" != "0" ]; then
		error_set "Unable to deploy file ${file} to maven repository ${repo_url}: $(error_get)"
	fi

	return $rv
}

# EOF
