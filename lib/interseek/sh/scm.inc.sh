#!/bin/bash

# Bash functions source control management (SCM) plugin
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

_SCM_VERSION="0.13";

_SCM_SVN=""
_SCM_CVS=""
_SCM_HG=""
_SCM_GIT=""
_SCM_BZR=""

#####################################################################
#                         PLUGIN FUNCTIONS                          #
#####################################################################

# returns version of this plugin
scm_version() {
	echo "${_SCM_VERSION}"
}

# initializes plugin
scm_init() {
	msg_debug "Looking for SCM installations in \$PATH."
	local cnt=0
	_SCM_SVN=$(which svn 2>/dev/null)
	test -x "${_SCM_SVN}" && {
		msg_debug "Found subversion: ${_SCM_SVN}"
		cnt=$((cnt + 1))
	}

	_SCM_CVS=$(which cvs 2>/dev/null)
	test -x "${_SCM_CVS}" && {
		msg_debug "Found cvs: ${_SCM_CVS}"
		cnt=$((cnt + 1))
	}

	_SCM_HG=$(which hg 2>/dev/null)
	test -x "${_SCM_HG}" && {
		msg_debug "Found mercurial: ${_SCM_HG}"
		cnt=$((cnt + 1))
	}

	_SCM_GIT=$(which git 2>/dev/null)
	test -x "${_SCM_SVN}" && {
		msg_debug "Found git: ${_SCM_GIT}"
		cnt=$((cnt + 1))
	}

	_SCM_BZR=$(which BZR 2>/dev/null)
	test -x "${_SCM_BZR}" && {
		msg_debug "Found bazaar: ${_SCM_BZR}"
		cnt=$((cnt + 1))
	}
	
	if [ ${cnt} -gt 0 ]; then
		msg_debug "Found ${cnt} different SCM client implementation(s)."	
		return 0
	fi
	
	msg_error "No SCM clients were found on system in \$PATH."
	return 1
}

# Prints type of SCM based by it's URL
#
# ARGUMENTS:
#	$1 (string, "")	:: SCM URL address
#
# RETURNS: 0 on recognized SCM URL, otherwise 1
_scm_type() {
	if echo "$1" | egrep -q '^:(.+):(.+)@(.+):.+' >/dev/null 2>&1; then
		echo "cvs"
	elif echo "$1" | egrep -q '^http(s)?://.+/' >/dev/null 2>&1; then
		echo "svn"
	elif echo "$1" | egrep -q '^file://.+' >/dev/null 2>&1; then
		echo "svn"
	elif echo "$1" | egrep -q '^svn(\+ssh|\+rsh)?://.+' >/dev/null 2>&1; then
		echo "svn"
	elif echo "$1" | egrep -q '^git://.+' >/dev/null 2>&1; then
		echo "git"
	else
		echo "unknown"
		return 1
	fi
	
	return 0
}

scm_export() {
	local var_name="${1}"
	local dir="${2}"
	
	if [ -z "${var_name}" -o -z "${dir}" ]; then
		error_set "Usage: scm_export \$scm_jobs \$dir"
		return 1
	fi

	local scm_jobs
	declare -a scm_jobs=$(var_as_str "${var_name}")

	if [ -z "${scm_jobs}" ]; then
		msg_warn "Empty scm jobs variable '${TERM_BOLD}${var_name}${TERM_RESET}'; nothing to do; returning success anyway."
		return 0
	fi

	local i=0
	while [ -n "${scm_jobs[${i}]}" ]; do
		local dest="${scm_jobs[${i}]}"
		i=$((i + 1))
		local scm_dir=$(echo "${dest}" | cut -d\| -f1)
		local dest_dir=$(echo "${dest}" | cut -d\| -f2)
		local flags=$(echo "${dest}" | cut -d\| -f3)
		
		# sanitize destination...
		dest_dir=$(_scm_sanitize "${dir}/${dest_dir}")
		msg_debug "DEST: ${dest}; SCM_DIR: ${scm_dir}; DIR: ${dest_dir}; FLAGS: ${flags}"

		# compute && fire real function name
		local scm_type=`_scm_type "$scm_dir"`
		if ! scm_export_${scm_type} "$scm_dir" "${dest_dir}" "${flags}"; then
			local err="SCM export failed"
			local e=$(error_get)
			if [ -z "$e" ]; then
				err="${err}."
			else
				err="${err}: $e"
			fi
			error_set "${err}"
			return 1
		fi
	done

	return 0
}

scm_export_cvs() {
	local root="$1"
	local dest_dir="$2"
	local flags="$3"
	
	# determine CVSROOT
	# ":ext:user@cvs.noviforum.si:/export/cvs:/some/module|/subdir"
	CVSROOT=$(echo "$root" | awk -F: '{print $1 ":" $2 ":" $3 ":" $4}')
	export CVSROOT
	# Load specified configuration file
	local cvs_mod=$(echo "$root" | awk -F: '{print $5 }' | sed -e 's/^\///g')

	# login to CVS server if necessary...
	if echo "$CVSROOT" | egrep '^:pserver:' >/dev/null 2>&1; then
		${_SCM_CVS} login || die "CVS login failed."
	fi
	
	# try to create tmpdir used to extract sources...
	local tmp_dir=$(mktemp -dt 2>/dev/null)
	test ! -z "$tmp_dir" -a -d "$tmp_dir" -a -w "$tmp_dir" || die "Unable to create temp directory for CVS extraction"
	test "$tmp_dir" = "/" && die "tmp_dir == / -> this should never happen!"

	# create destination directory
	mkdir -p "$dest_dir" || die "Unable to create destination dir '$dest_dir'."

	# cleanup tmp dir...
	mkdir -p "$tmp_dir" || die "Unable to create temp dir."
	# remove everything from tmpdir
	rm -rf "${tmp_dir}"/* >/dev/null 2>&1
	
	local cvs_revision=$(parse_flags "$flags" "revision")
	local cvs_date=$(parse_flags "$flags" "date")
	test -z "$cvs_revision" -a -z "$cvs_date" && cvs_revision="HEAD"

	# build export flags
	local cvs_export_flags=""
	test ! -z "$cvs_revision" && cvs_export_flags="${cvs_export_flags} -r ${cvs_revision}"
	# this line has a possible bug... -D requires single argument...
	test ! -z "$cvs_date" && cvs_export_flags="${cvs_export_flags} -D '${cvs_date}'"

	# export sources from CVS... finally..
	msg_info "    Exporting destination (${TERM_LRED}CVS${TERM_RESET}) ${TERM_YELLOW}$cvs_mod${TERM_RESET} branch/date '${TERM_LBLUE}$cvs_revision/${cvs_date}${TERM_RESET}' to '${TERM_LGREEN}$dest_dir${TERM_RESET}'."
	(
		cd "$tmp_dir" && \
		${_SCM_CVS} $CVS_FLAGS export ${cvs_export_flags} "${cvs_mod}" && \
		cd "$cvs_mod" && \
		tar cpf - * | tar xpf - -C "${dest_dir}"
	) || die "CVS export error."
	
	# destroy tmp direcory
	rm -rf "${tmp_dir}" >/dev/null 2>&1

	return 0
}

scm_export_svn() {
	local root="$1"
	local dest_dir="$2"
	local flags="$3"
	
	msg_debug "root: '${root}'; dest_dir: '${dest_dir}'; flags: '${flags}'."

	# get flags
	local svn_user=$(parse_flags "${flags}" "username")
	local svn_pass=$(parse_flags "${flags}" "password")
	local svn_rev=$(parse_flags "${flags}" "revision")
	
	# build export options...
	local svn_export_opt="-q --force --no-auth-cache"
	test ! -z "${svn_rev}" && svn_export_opt="${svn_export_opt} --revision ${svn_rev}"
	test ! -z "${svn_user}" && svn_export_opt="${svn_export_opt} --username ${svn_user}"
	test ! -z "${svn_pass}" && svn_export_opt="${svn_export_opt} --password ${svn_pass}"
	
	msg_debug "SVN export command line options: ${svn_export_opt}"

	# try to create destination directory
	if ! mkdir -p "${dest_dir}"; then
		error_set "Unable to create destination directory '${dest_dir}'."
		return 1
	fi

	test -z "$svn_rev" && svn_rev="HEAD"

	# export sources from SVN
	msg_info "    Exporting destination (${TERM_LRED}SVN${TERM_RESET}) '${TERM_YELLOW}${root}${TERM_RESET}' revision '${TERM_LBLUE}${svn_rev}${TERM_RESET}' to '${TERM_LGREEN}${dest_dir}${TERM_RESET}'."
	msg_debug "Running: ${_SCM_SVN} export ${svn_export_opt} ${root} ${dest_dir}"
	if ! ${_SCM_SVN} export $svn_export_opt "${root}" "${dest_dir}"; then
	 	error_set "SVN export error: exit code: $?"
	 	return 1
	fi

	# this is it folx...
	return 0
}

scm_export_hg() {
	die "HG support is not implemented yet."
}

scm_export_git() {
	local root="$1"
	local dest_dir="$2"
	local flags="$3"
	
	# remove possible git:// url prefix...
	root=$(echo "${root}" | sed -e 's/git:\/\///g')

	# get tag & branch...
	local git_tag=$(parse_flags "${flags}" "tag")
	local git_branch=$(parse_flags "${flags}" "branch")
	local git_subdir=$(parse_flags "${flags}" "subdir")

	if [ ! -z "${git_tag}" -a ! -z "${git_branch}" ]; then
		error_set "Git tag and branch are set, don't know what to check out..."
		return 1
	fi

	msg_debug "root: '${root}'; dest_dir: '${dest_dir}'; flags: '${flags}'."
	
	# create temporary directory
	local tmpdir=$(mktemp -d -q 2>/dev/null)
	test -z "${tmpdir}" && {
		error_set "Error creating temporary directory."
		return 1
	}
	
	# remove temporary directory (git clone doesn't work with existing
	# directories in older versions of git.)
	rm -rf "${tmpdir}" || die "Unable to remove temporary directory."
	
	local git_opt="-q"
	
	# perform git clone
	msg_info "    Exporting destination (${TERM_LRED}GIT${TERM_RESET}) '${TERM_YELLOW}${root}${git_subdir}${TERM_RESET}' to '${TERM_LGREEN}${dest_dir}${TERM_RESET}'."
	msg_debug "Running: ${_SCM_GIT} clone ${git_opt} ${root} ${tmpdir}"
	${_SCM_GIT} clone ${git_opt} "${root}" "${tmpdir}" || {
		error_set "GIT clone error: exit code: $?"
		rm -rf "${tmpdir}"
		return 1
	}

	# do we want to checkout specific tag?
	local checkout_item=""
	if [ ! -z "${git_tag}" ]; then
		checkout_item="${git_tag}"
	# or maybe specific branch?
	elif [ ! -z "${git_branch}" ]; then
		checkout_item="${git_branch}"
	fi
	if [ ! -z "${checkout_item}" ]; then
		msg_verbose "      Checking out ${TERM_BOLD}${checkout_item}${TERM_RESET}."
		# enter directory
		local cwd=$(pwd)
		cd "${tmpdir}" || {
			error_set "Unable to enter temporary git export: '${tmpdir}'"
			rm -rf "${tmpdir}"
			return 1
		}
		if ! ${_SCM_GIT} checkout -f -q "${checkout_item}"; then
			error_set "Unable to check out branch/tag '${checkout_item}'. Are you sure, that this branch/tag exist?"
			cd "${cwd}" >/dev/null 2>&1
			rm -rf "${tmpdir}" >/dev/null 2>&1
			return 1
		fi
		# go back...
		cd "${cwd}" || {
			error_set "Unable to go back to '${pwd}' after git checkout."
			rm -rf "${tmpdir}" >/dev/null 2>&1			
			return 1
		}
	fi

	# do we have subdir?
	if [ ! -d "${tmpdir}/${git_subdir}" ]; then
		error_set "Exported Git tree doesn't contain '${git_subdir}' subdirectory."
		rm -rf "${tmpdir}"
		return 1
	fi

	# remove .git directory...
	rm -rf "${tmpdir}/.git" || {
		error_set "Unable to remove git metadata directory: ${tmpdir}/.git"
		rm -rf "${tmpdir}" >/dev/null 2>&1
		return 1
	}
	
	# now copy tmpdir contents to real destination
	( cd "${tmpdir}/${git_subdir}" && tar -cpf - * | tar -xpf - -C "${dest_dir}" ) || {
		error_set "Unable to copy git cloned data from temporary directory to ${dest_dir}"
		rm -rf "${tmpdir}" >/dev/null 2>&1
		return 1
	}

	# remove tmp dir
	rm -rf "${tmpdir}" >/dev/null 2>&1

	# we survived :)	
	return 0
}

scm_export_bzr() {
	die "GIT support is not implemented yet."
}

scm_export_unknown() {
	die "Unknown SCM repository URL '${TERM_LRED}$1${TERM_RESET}'."
}

_scm_sanitize() {
	echo "$@" | sed -e 's/\.\.//g' | sed -e 's/\/\//\//g'
}

# EOF
