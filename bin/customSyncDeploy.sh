#!/bin/bash

# Flexible rsync based synchronization/deployment script.
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
#                GLOBAL CONFIGURATION VARIABLES                     #
#####################################################################

#   **** SCRIPT FLOW ****
#
# * create tmpdir ${TMP_DIR}
# * create tmpdir ${SRC_DIR}
#
# * unpack command line defined source (file, directory, url or maven artifact)
#   to ${SRC_DIR}
#
# * run hooks using variable ${HOOK_PRE_DEPLOY}
#
# FOREACH ${DESTINATION} from variable ${DEPLOY_DEST} DO
#
#    * run hooks using variable ${HOOK_PRE_DESTINATION_DEPLOY}
#    * deploy content of ${SRC_DIR} to ${DESTINATION} using rsync ${RSYNC_OPT}
#    * run hooks using variable ${HOOK_POST_DESTINATION_DEPLOY}
#
# DONE
#
# * run hooks using variable ${HOOK_POST_DEPLOY}
#
# * run hooks using variable ${HOOK_EXIT_OK} if deployment was successful
# * run hooks using variable ${HOOK_EXIT_FAILED} if deployment failed

# Additional rsync command line options
#
# NOTE: If rsync options are not specified, default 
#       value of '-ra' is used.
#
# Type: string
# Default: ""
RSYNC_OPT=""

# Temporary working directory
#
# Type: string
# Default: "/tmp"
#
TMP_DIR="/tmp"

# Ask for confirmation before deploying to
# specific destination?
#
# Type: boolean
# Default: 0
INTERACTIVE_MODE="0"

# Deploy destinations
#
# NOTE: in each element you can use any bash variable
#       and strftime(3) placeholders...
# Example:
# 	DEPLOY_DEST=(
#		'user@host.example.org:frontend/webroot/action_name'
#		'host.example.org::action_module/'
#	)
# 
# Type: bash array
# Default: ()
DEPLOY_DEST=()

# Commands to run *BEFORE* deployment to remote destination(s)
# has been started.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${SRC_DIR}	:: temporary directory with source contents
#
#
# Type: array
# Default: ()
HOOK_PRE_DEPLOY=()

# Commands to run *BEFORE* deployment to specific
# destination from $DEPLOY_DEST
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${SRC_DIR}	:: temporary directory with source contents
#   ${DEST_URL} :: full destination address (full entry from $DEPLOY_DEST)
#   ${DEST_HOST}:: destination hostname (if any)
#   ${DEST_USER}:: destination username (if any)
#   ${DEST_DIR} :: destination directory (if any)
#
# Type: array
HOOK_PRE_DESTINATION_DEPLOY=()

# Commands to run *AFTER* deployment to specific
# destination from $DEPLOY_DEST
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${SRC_DIR}	:: temporary directory with source contents
#   ${DEST_URL} :: full destination address (full entry from $DEPLOY_DEST)
#   ${DEST_HOST}:: destination hostname (if any)
#   ${DEST_USER}:: destination username (if any)
#   ${DEST_DIR} :: destination directory (if any)
#
# Type: array
HOOK_POST_DESTINATION_DEPLOY=()

# Commands to run *AFTER* deployment has been done to
# remote destination(s).
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${SRC_DIR}	:: temporary directory with source contents
#
#
# Type: array
# Default: ()
HOOK_POST_DEPLOY=()

# WWW retrieval username
#
# Type: string
# Default: ""
WWW_USERNAME=""

# WWW retrieval password
#
# NOTE: if username is defined and if this
#       directive is empty, password will
#       queried from the command prompt.
#
# Type: string
# Default: ""
WWW_PASSWORD=""

# artifactDeploy.pl additional command line options
#
# NOTE: Option -f|--force is always prepended!
#
# Type: string
# Default: ""
AD_OPT=""

# Deploy Maven artifacts in unpacked form?
#
# Note: Maven artifacts are fetched using tricon
#       artifactDeploy.pl script
#
# Type: boolean
# Default: 1
MVN_UNPACKED="1"

# Comment out the following line
# to make this configuration file valid
# die "${TERM_BOLD}You haven't edited default configuration file, have you boy? :)${TERM_RESET}"

# EOF

#####################################################################
#                            FUNCTIONS                              #
#####################################################################

VERSION="0.31";
MYNAME=$(basename $0)
TO_CLEANUP=""
NO_CLEANUP="0"
NO_TMPDIR="0"
FORCE="0"

basedir_get() {
	local me=$(readlink -f "${0}")
	local dir=$(dirname "${me}")
	dir=$(dirname "${dir}")
	
	echo "${dir}"
}

printhelp() {
	cat <<EOF
Usage: ${MYNAME} -c file.conf [OPTIONS] <dir|file_archive|URL|maven.group.artifact>

Flexible rsync based synchronization/deployment script. Deployment destinations
are stored in configuration file, deployment source is provided from command line.

Script is able to deploy data from:

 * local directory
 * local compressed file (zip, tar, tgz, tbz)
 * compressed file on remote HTTP server
 * Maven remote repository (requires tricon/artifactDeploy.pl)

OPTIONS:
  -c   --config          Loads configuration specified configuration file
       --default-config  Prints default configuration file
       --no-cleanup      Don't remove temporary directories on exit
  
  -N   --no-tmpdir       Don't copy contents of source directory to temporary
                         directory before running pre-deploy hooks and deploying
                         to remote machines.
                         (Default: ${NO_TMPDIR})
                         NOTE: This works only with local directory sources
                         WARNING: Bad pre-deploy hooks can corrupt original data
                                  directory!!!

  -A   --ad-opt          Additional artifactDeploy.pl command line options
                         (Default: "${AD_OPT}")
       
       --mvn-unpacked    Deploy maven artifacts in unpacked form (Default: "${MVN_UNPACKED}")
  -P   --mvn-packed      Deploy maven artifacts in packed form
  
  -i    --interactive    Confirm each action taken (Default: "${INTERACTIVE_MODE}")

  -f   --force           Forced exection
  -v   --verbose         Verbose execution
  -q   --quiet           Quiet execution
  -D   --debug           Enables debugging messages
  -T   --time-stamps     Enables timestamps in printed messages
  -V   --version         Prints script version 
  -h   --help            This help message

EXAMPLES:

# deploy directory with copying it's contents to temporary directory
# before syncing
  ${MYNAME} -c file.conf /path/to/directory

# deploy directory without copying it's contents to temporary directory
# before syncing
  ${MYNAME} -c file.conf -N /path/to/directory

# deploy local file archive (makeWar2.sh created webappa archive)
# Supported archives: zip, war, jar, tar, tar.gz, tar.bz2
  ${MYNAME} -c file.conf /path/to/file.zip

# deploy file archive located on http server
  ${MYNAME} -c file.conf http://host.example.org/path/to/file.zip

# deploy Maven artifact in unpacked form
# Run deployArtifact.pl --help for additional instructions
  ${MYNAME} -c file.conf com.example.artifact

# deploy Maven artifact in original, packed form
# Run deployArtifact.pl --help for additional instructions
  ${MYNAME} -c file.conf -P com.example.artifact
EOF
}

tmpdir_create() {
	local dir=$(mktemp -d -p "${TMP_DIR}" "${MYNAME}.XXXXXX" 2>/dev/null)
	test -z "${dir}" && my_die "Unable to create temporary directory in ${TMP_DIR}"
	echo "${dir}"
}

my_die() {
	hook_run "HOOK_EXIT_FAILED"
	exit_cleanup
	die "$@"
}

my_exit() {
	local code="$1"
	hook_run "HOOK_EXIT_OK"
	exit_cleanup
	msg_info "Execution of ${TERM_LGREEN}${MYNAME}${TERM_RESET} finished on $(hostname) at $(date)"
	exit ${code}
}

exit_cleanup() {
	msg_debug "Startup."
	local e=""
	for e in ${TO_CLEANUP}; do
		test -z "${e}" && continue
		test "${e}" = "/" && continue
		test "${e}" = "/tmp" && continue
		test "${e}" = "/root" && continue

		if [ "${NO_CLEANUP}" = "0" -a -e "${e}" ]; then
			msg_verbose "Cleaning up ${TERM_BOLD}${e}${TERM_RESET}"
			rm -rf "${e}" >/dev/null 2>&1
		fi
	done
}

dest_env_vars() {
	local dest="$1"
	test -z "${dest}" && {
		error_set "Undefined destination."
		return 1
	}

	# destroy old variables
	unset DEST_URL DEST_DIR DEST_HOST DEST_USER

	local url="$dest"
	local user=$(echo "${dest}" | cut -d@ -f1)
	local host=$(echo "${dest}" | cut -d@ -f2 | cut -d: -f1)

	# rsync over ssh?
	local dir=$(echo "${dest}" | cut -d@ -f2 | cut -d: -f2)
	# rsync using rsync server?
	test -z "${dir}" && dir=$(echo "${dest}" | cut -d@ -f2 | cut -d: -f3)

	# check for injuries...
	if [ -z "${dir}" ]; then
		error_set "Invalid destination syntax: '$dest'"
		return 1
	fi

	# establish new ones :)
	export DEST_URL="${url}"
	export DEST_DIR="${dir}"
	export DEST_HOST="${host}"
	export DEST_USER="${user}"

	msg_debug "Created env vars for destination '$dest': DEST_URL: '$DEST_URL', DEST_HOST: '$DEST_HOST', DEST_USER: '$DEST_USER', DEST_DIR: '$DEST_DIR'"
	return 0
}

action_deploy() {
	local dir="${1}"
	local cwd=$(pwd)
	
	msg_debug "Entering directory: ${dir}"
	if ! cd "${dir}"; then
		error_set "Unable to enter directory: ${dir}"
		return 1
	fi
	
	hook_run "HOOK_PRE_DEPLOY" || return 1
	
	# build rsync options!
	local opt="${RSYNC_OPT}"
	test -z "${opt}" && opt="-ra"
	
	# deploy to each and every destination
	local i=0
	while [ -n "${DEPLOY_DEST[${i}]}" ]; do
		local dest=$(shell_pattern_resolve "${DEPLOY_DEST[${i}]}")
		i=$((i + 1))
		test -z "${dest}" && continue

		# create destination environment variables
		dest_env_vars "${dest}" || {
			msg_warn "Invalid destination: $(error_get)"
			continue
		}
		
		# should we ask to deploy?
		if [ "${INTERACTIVE_MODE}" = "1" ]; then
			if ! question_tf "Ready to deploy to ${TERM_LRED}${dest}${TERM_RESET}?" "n"; then
				msg_warn "Skipping location ${dest}"
				continue
			fi
		else
			msg_info "Processing destination: ${TERM_LGREEN}${dest}${TERM_RESET}"
		fi

		# msg_info "Destination: ${TERM_BOLD}${dest}${TERM_RESET}"

		# run pre destination deploy hooks
		if ! hook_run "HOOK_PRE_DESTINATION_DEPLOY"; then
			if [ "${FORCE}" != "1" ]; then
				test "${INTERACTIVE_MODE}" = "1" && {
					if question_tf "Pre-destination deploy hook failed, try to deploy to next destination?" "n"; then
						continue
					fi
				}
				return 1
			else
				msg_warn "$(error_get); force switch in effect."
			fi
		fi

		# do the deploy!
		msg_info "${TERM_BOLD}Performing deployment.${TERM_RESET}"
		msg_debug "Running: rsync ${opt} . ${dest}"
		if ! rsync ${opt} . "${dest}"; then
			if [ "${FORCE}" != "1" ]; then
				if [ "${INTERACTIVE_MODE}" = "1" ]; then
					if question_tf "Deployment ${TERM_LRED}${dest}${TERM_RESET} failed; try to deploy next node?" "n"; then
						continue
					fi
				else
					error_set "Error deploying to: ${dest}"
					return 1
				fi
			else
				msg_warn "$(error_get); force switch in effect, skipping."
				continue
			fi
		fi

		# run post destination deploy hooks
		if ! hook_run "HOOK_POST_DESTINATION_DEPLOY"; then
			if [ "${FORCE}" != "1" ]; then
				test "${INTERACTIVE_MODE}" = "1" && {
					if question_tf "Post-destination deploy hook failed, try to deploy to next destination?" "n"; then
						continue
					fi
				}
				return 1
			else
				msg_warn "$(error_get); force switch in effect."
			fi
		fi
	done

	msg_debug "Returning back to directory: ${cwd}"
	if ! cd "${cwd}"; then
		error_set "Unable to return to directory: ${dir}"
		return 1
	fi
	
	hook_run "HOOK_POST_DEPLOY" || return 1

	return 0
}

action_unpack() {
	local src="${1}"
	local dst="${2}"

	# is source a filesystem object?
	if [ -e "${src}" ]; then
		action_unpack_fs "${src}" "${dst}"
		return $?
	# it must be an url address then...
	elif echo "${src}" | egrep -qi '^(htt|ft)p(s)?://'; then
		action_unpack_www "${src}" "${dst}"
		return $?
	elif ! echo "${src}" | grep -qi '\/'; then
		# try using artifactDeploy.pl...
		action_unpack_ad "${src}" "${dst}"
		return $?
	else
		error_set "Invalid source: '${src}'"
		return 1
	fi

	return 0	
}

action_unpack_fs() {
	local src="${1}"
	local dst="${2}"
	
	if [ -d "${src}" ]; then
		# source is directory...
		# is -N|--no-tmpdir in effect?
		if [ "${NO_TMPDIR}" = "1" ]; then
			# we won't copy anything, therefore
			# we need to change $WEBAPP_DIR variable
			msg_verbose "Source is directory, option NO_TMPDIR is in effect, changing variable WEBAPP_DIR."
			SRC_DIR="${src}"
			WEBAPP_DIR="${src}"
			return 0
		else
			# copy all directory contents to destination directory...
			msg_verbose "Copying contents of '${src}' to temporary directory '${dst}'."
			if ! ( cd "${src}" && cp -ra . "${dst}"); then
				error_set "Unable to copy contents of directory '${src}' to '${dst}'"
				return 1
			fi
		fi
	elif [ -f "${src}" ]; then
		# it must be some kind of an archive;
		# try to unpack it
		archive_unpack "${src}" "${dst}"
		return $?
	else
		error_set "Invalid filesystem source: '${src}'"
		return 1
	fi

	return 0
}

action_unpack_www() {
	local src="${1}"
	local dst="${2}"

	# try to download the goddamn archive...
	local tmpf="${TMP_DIR}/$(basename "${src}")"
	
	# compute wget opt...
	local opt="--no-check-certificate"
	test ! -z "${WWW_USERNAME}" && opt="${opt} --user=${WWW_USERNAME}"
	test ! -z "${WWW_PASSWORD}" && opt="${opt} --user=${WWW_PASSWORD}"
	opt="${opt} -q"

	msg_info "Downloading webbapp archive ${TERM_YELLOW}${src}${TERM_RESET} to ${TERM_BOLD}${tmpf}${TERM_RESET}"
	msg_debug "Running: wget ${opt} -O ${tmpf} ${src}"
	if ! wget ${opt} -O "${tmpf}" "${src}"; then
		error_set "Unable to download ${src}: wget exit code $?"
		return 1
	fi
	msg_info "Download was successful."
	
	# now just extract the goddamn archive
	action_unpack_fs "${tmpf}" "${dst}"
	return $?
}

action_unpack_ad() {
	local src="${1}"
	local dst="${2}"

	# artifactDeploy.pl options
	local opt="-f"
	verbose_status 0 && opt="${opt} --verbose"
	debug_status 0 && opt="${opt} --debug"
	test ! -z "${AD_OPT}" && opt="${opt} ${AD_OPT}"	

	local tmp_archive_name="archive.zip"
	local deploy_dir="${TMP_DIR}"

	if [ "${MVN_UNPACKED}" = "1" ]; then
		# remove anything after ',' character...
		src=$(echo "${src}" | awk -F ',' '{print $1}')

		# force deploy archive name if UNPACKED deployment was requested.
		src="${src},${tmp_archive_name}"
	else
		# change deploy directory if user requests PACKED deployment
		test "${MVN_UNPACKED}" != "1" && deploy_dir="${dst}"	
	fi

	# try to fetch it with artifactDeploy.pl
	msg_verbose "Running: artifactDeploy.pl ${opt} deploy_simple ${TMP_DIR} ${src}"
	if ! artifactDeploy.pl ${opt} deploy_simple "${deploy_dir}" "${src}"; then
		error_set "artifactDeploy.pl fetch failed: exit code $?"
		return 1
	fi
	
	if [ "${MVN_UNPACKED}" = "1" ]; then
		# now just extract the goddamn archive
		action_unpack_fs "${deploy_dir}/${tmp_archive_name}" "${dst}"	
	fi

	return $?
}

run() {
	local src="${1}"
	if [ -z "${src}" ]; then
		error_set "Undefined source file/url/directory/artifactId."
		return 1
	fi

	msg_info "Starting ${TERM_LGREEN}${MYNAME}${TERM_RESET} version ${TERM_YELLOW}${VERSION}${TERM_RESET} on $(hostname) at $(date)"
	
	# create temporary directory...
	local dir=$(tmpdir_create)
	msg_verbose "Created temporary directoy: ${TERM_BOLD}${dir}${TERM_RESET}"
	local target_dir="${dir}/target"
	TO_CLEANUP="${TO_CLEANUP} ${dir}"

	# add magic global vars :)
	TMP_DIR="${dir}"
	SRC_DIR="${target_dir}"
	WEBAPP_DIR="${target_dir}"
	DEPLOY_SOURCE="${src}"
	
	# export variables
	export TMP_DIR SRC_DIR WEBAPP_DIR DEPLOY_SOURCE

	# create target directory...
	mkdir -p "${target_dir}" || die "Unable to create target directory: ${target_dir}"

	# unpack source to temporary directory
	action_unpack "${src}" "${target_dir}" || return 1

	# perform deployment!
	action_deploy "${SRC_DIR}/" || return 1
	
	return 0
}

#####################################################################
#                              MAIN                                 #
#####################################################################

# try to load functions
file=$(basedir_get)"/lib/interseek/sh/functions.inc.sh"

if [ ! -f "$file" ]; then
	echo "Unable to load functions file: ${file}" 1>&2
	exit 1
fi
. "$file"

# parse command line...
TEMP=$(getopt -o c:NA:PifDTqvVh --long config:,default-config,no-cleanup,no-tmpdir,ad-opt:,mvn-unpacked,mvn-packed,interactive,no-interactive,force,quiet,verbose,debug,time-stamps,version,help -n "$MYNAME" -- "$@")
eval set -- "$TEMP"
while true; do
	case $1 in
		-c|--config)
			config_load "$2" "${WWW_USERNAME}" "${WWW_PASSWORD}" || my_die
			shift 2
			;;
		--default-config)
			config_default_print 21 186
			exit 0
			;;
		--no-cleanup)
			NO_CLEANUP=1
			shift
			;;
		-N|--no-tmpdir)
			NO_TMPDIR=1
			shift
			;;
		-A|--ad-opt)
			AD_OPT="${2}"
			shift 2
			;;
		--mvn-unpacked)
			MVN_UNPACKED=1
			shift
			;;
		-P|--mvn-packed)
			MVN_UNPACKED=0
			shift
			;;
		-i|--interactive)
			INTERACTIVE_MODE=1
			shift
			;;
		--no-interactive)
			INTERACTIVE_MODE="0"
			shift
			;;
		-f|--force)
			FORCE=1
			shift
			;;
		-q|--quiet)
			quiet_enable
			shift
			;;
		-v|--verbose)
			verbose_enable
			shift
			;;
		-D|--debug)
			debug_enable
			shift
			;;
		-T|--time-stamps)
			msg_func_ts_enable
			shift
			;;
		-V|--version)
			printf "%s %-.2f\n" "${MYNAME}" "${VERSION}"
			exit 0
			;;
		-h|--help)
			printhelp
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			die "Command line parsing error: '$1'."
			;;
	esac
done

# load required modules...
plugin_load "archive" 1

# i really love this one
run "$@" || my_die

my_exit 0

# EOF
