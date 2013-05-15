#!/bin/bash

# Flexible webapp archive creation script.
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
#                 makeWar2.sh GLOBAL VARIABLES                      #
#####################################################################

#   **** SCRIPT FLOW ****
#
# * create tmpdir ${WEBAPP_TMP}
# * create temporary webapp root directory ${WEBAPP_DIR} = "${WEBAPP_TMP}/target"
#
# * IF "${DIR_SYNC_BEFORE_SCM_EXPORT}" = "1" THEN
#
#     * run hooks using variable ${HOOK_PRE_DIR_SYNC}
#     * run directory synchronization using variable ${SYNC_DIRS}
#     * run hooks using variable ${HOOK_POST_DIR_SYNC}
# 
#     * run hooks using variable ${HOOK_PRE_SCM_EXPORT}
#     * export sources from SCM using variable ${SCM_PROJECTS}
#     * run hooks using variable ${HOOK_POST_SCM_EXPORT}
#
#   ELSE
#
#     * run hooks using variable ${HOOK_PRE_SCM_EXPORT}
#     * export sources from SCM using variable ${SCM_PROJECTS}
#     * run hooks using variable ${HOOK_POST_SCM_EXPORT}
#
#     * run hooks using variable ${HOOK_PRE_DIR_SYNC}
#     * run directory synchronization using variable ${SYNC_DIRS}
#     * run hooks using variable ${HOOK_POST_DIR_SYNC}
#
#   ENDIF
#
#   * optionally create build settings file ${BUILD_SETTINGS}
#   * run hooks using variable ${HOOK_PRE_WAR_CREATE}
#   * biuld webapp archive using maven or static build type, depending
#     on value of variable ${BUILD_TYPE}
#   * run hooks using variable ${HOOK_POST_WAR_CREATE}
#   * deploy webapp archive to file specified by variable ${WAR_ARCHIVE_NAME}
#   * optionally deploy webapp archive	to maven repository manager using mvn(1)
#
#   * run hooks using variable ${HOOK_EXIT_OK} if build was successful
#   * run hooks using variable ${HOOK_EXIT_FAILED} if build failed

# Webapp build type
#
# Possible values: maven, static, make, grunt
#
# Type: string
# Default: "static"
BUILD_TYPE="static"

# Final name of created webapp archive name.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: Package-type is recognized by file suffix
# WARNING: Filename must have suffix ".zip" if ${BUILD_TYPE}
#       set to "static"
#
# Type: string
# Default: '/tmp/webapp-example-%Y%m%d-%H%M%S.war'
#
WAR_ARCHIVE_NAME='/tmp/webapp-example-%Y%m%d-%H%M%S.war'

# Temporary working directory
#
# Type: string
# Default: "/tmp"
#
TMP_DIR="/tmp"

# Run custom directory synchronization BEFORE
# exporting sources from Source Control Management (SCM)
# systems?
#
# Type: boolean
# Default: 0
#
DIR_SYNC_BEFORE_SCM_EXPORT=0

# List of SCM => directory paths.
# 
# Each listed scm path will be exported to corresponding
# subdirectory (relative to $FRONTEND_DIR).
#
# GENERAL SYNTAX:
#	"SCM_URL|frontend_relative_extract_path[|FLAGS]"
#
# 	CVS SYNTAX:
#		":connection_method:username@hostname:cvs_root:/module|extract_path[|FLAGS]"
#
#	FLAGS:
#		+ revision	:: [type: string; default: "HEAD"]
#						CVS revision/branch
#		+ date		:: [type: string; default: ""]
#						commit date (can be also set to 'now')
#
#		CVS EXAMPLES:
#			+ ":ext:user@cvs.example.org:/export/cvs:/some/module|/subdir"
#			+ ":ext:user@cvs.example.org:/export/cvs:/some/module_2|/"
#			+ ":ext:user@cvs.example.org:/export/cvs:/some/module_3|/|revision=some_funny_branch,date=1 month ago"
#
#	SUBVERSION SYNTAX:
# 		"repository_url|/extract_path[|FLAGS]"
#
#	FLAGS:
#		+ username :: [type: string; default: ""]
#			 			repository username
#
#		+ password :: [type: string; default: ""]
#						repository authentication password
#
#		+ revision :: [type: string; default: "HEAD"]
#						repository revision
#
#	 	SVN EXAMPLES:
#			+ "svn://svn.example.org/repository|/tmp|username=a,password=b"
#			+ "svn+ssh://svn.example.org/repository|/tmp|username=a"
#			+ "https://svn.example.org/repository|/tmp|username=a"
#
#
#   GIT SYNTAX:
#       "git://user@host:/path/to/repo.git|/extract_path[|FLAGS]"
#
#   FLAGS:
#       + branch :: [type: string, default: ""]
#                      Checkout specific branch
#
#       + tag    :: [type: string, default: ""]
#                      Checkout specific tag
#
#       + subdir :: [type: string, default: ""]
#                      Checkout git repository subdirectory 
#
#      GIT EXAMPLES:
#          + "git://git@host.example.com:something.git|/tmp|tag=v2.0"
#          + "git://git@host.example.com:something.git|/tmp|tag=v2.0,subdir=/something"
#
# Type: array of strings
# Default: empty array
#
SCM_PROJECTS=()

# Array of commands that are going to be run
# *BEFORE* SCM export.
# 
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_PRE_SCM_EXPORT=()

# Array of commands that are going to be run
# *AFTER* SCM export
# 
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_POST_SCM_EXPORT=()

############################################
#         Directory synchronization        #
############################################

# List of directories, files and URLs, that needs to be
# sychronized to webapp after SCM sources have been exported.
# 
# You probably want to synchronize your production
# configuration properties files, toolbar, etc from
# your referential repositories to frontend
# directory.
#
# SYNTAX:
#
# "{filesystem_path|url_address}|{frontend_dir_relative_path}[|FLAGS]"
#
# This directive updates referential repository located in work directory
# related path from some folder located on local filesystem or URL address.
#
# FILESYSTEM PATH (copy file/s from a local filesystem)
#
# URL ADDRESS (fetch files from url address)
#		Supported URL schemes:
#		+ http://, https://, ftp://
# 
# FLAGS:
#		+ cleanup		:: [type: boolean; default: 0]
#						Remove all contents from destination folder before
#						synchronization
#
#		+ archive		:: [type: boolean; default: 0]
#						Tread downloaded file as a file archive.
#						If url address has a valid suffix, then archive will be
#						extracted on it's suffix.
#						Currently supported archives:
#						JAR, ZIP, gzipped tar, b2zipped tar
#
#		+ archive_suffix	:: [type: string; default: ""]
#						This option is evaluated *ONLY* when option "archive" is
#						set to value of 1. When set to nonempty value, this value
#						will be appended to filename in order to determine archive
#						type.
#
#       + unpack_flags  :: [type: string; default ""]
#                       This option adds additional archive-type specific unpack
#                       flags. This option is considered *ONLY* when option "archive"
#                       is set to value of 1. Example: Set this to "-KX" for zip
#                       archives if you want to perserve file uid/gids on unpacked
#                       files.
#
# EXAMPLES:
#
#		+ "http://update.example.org/jars/issi/latest|/WEB-INF/lib|archive=1,archive_suffix=tbz"
#		+ "/path/to/directory|somedir|move=1"
#
#
# Type: array of strings
# Default: empty array
#
SYNC_DIRS=()

# Array of commands that are going to be run
# *BEFORE* synchronizing directories to WAR dir.
# 
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_PRE_DIR_SYNC=()

# Array of commands that are going to be run
# *AFTER* synchronizing directories to WAR dir.
# 
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_POST_DIR_SYNC=()

############################################
#            WAR file variables            #
############################################

# Array of commands that are going to be run
# *BEFORE* WAR creation.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_PRE_WAR_CREATE=()

# Array of commands that are going to be run
# *AFTER* WAR creation.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#	${ARCHIVE}		:: finished webapp archive filename
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_POST_WAR_CREATE=()

# Space separated list of filesystem paths
# in which newly created webapp archive 
# will be copied.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#	${ARCHIVE}		:: finished webapp archive filename
#
# Type: array of strings
# Default: empty array
#
WAR_DEST_EXTRA=()

# Array of commands that are going to be run
# *BEFORE* copying WAR to specified locations.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#	${ARCHIVE}		:: finished webapp archive filename
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_PRE_WAR_DEST_EXTRA=()

# Array of commands that are going to be run
# *AFTER* copying WAR to specified locations.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#	${ARCHIVE}		:: finished webapp archive filename
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_POST_WAR_DEST_EXTRA=()

############################################
#             Maven variables              #
############################################

# Deploy generated webapp file file to maven repository?
#
# NOTE: if you're building static webapp, you must set
#       variable $WAR_ARCHIVE_NAME to filename that ends
#		with suffix '.zip'
#
# NOTE: YES, YOU CAN deploy non-java webapp to maven
#		repository :)
#
# Type: boolean
# Default: 0
MVN_DEPLOY="0"

# Maven artifactId
#
# Type: string
# Default: ""
MVN_ARTIFACT_ID=""

# Maven groupId
#
# Type: string
# Default: "org.example.production.webapps"
MVN_GROUP_ID="org.example.production.webapps"

# Maven artifact version
#
# Type: string
# Default: ""
MVN_ARTIFACT_VERSION=""

# Maven repository id
#
# Type: string
# Default: "example-maven-repository-releases"
MVN_REPOSITORY_ID="example-maven-repository-releases"

# Maven repository url
#
# Type: string
# Default: "https://mvnrepo.example.org/content/repositories/internal-releases"
MVN_REPOSITORY_URL="https://mvnrepo.example.org/content/repositories/internal-releases"

# Maven additional command line arguments
#
# HINT: You can set this to '-q -U' if you
#       know what you're doing...
#
# Type: string
# Default: ""
MVN_OPT=""

# If you're building webapp which is submodule of some
# multimodule maven project, set this submodule name.
# 
# Example: set this to 'identity-server' for
#          identity-project webapp.
#
# Type: string
# Default: ""
MVN_WAR_DIR=""

############################################
#             Make variables               #
############################################

# Make additional command line arguments
#
#
# Type: string
# Default: ""
MAKE_OPT=""

############################################
#       Miscellaneous variables            #
############################################

# Path to simple text file inside webapp where
# webapp build (makeWar2) configuration is going
# to be written. If empty, configuration will not
# written. Passwords used for variables SCM_PROJECTS
# and SYNC_DIRS are stripped out of strings...
# 
# Type: string
# Default: ""
BUILD_SETTINGS=""

# Array of commands that are going to be run
# when all operations defined in configuration
# file were successful and script wants to exit
# with succes error code.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_EXIT_OK=()

# Array of commands that are going to be run
# when any operations defined in configuration
# file fails.
#
# NOTE: This string supports strftime(3) placeholders.
# NOTE: This variable can contain shell variable expressions
# NOTE: Write commands using single quotes.
#
# Available shell variables:
#	${WEBAPP_DIR}	:: temporary directory used for webapp archive creation
#
# Type: array of of eval(1) strings
# Default: empty array
#
HOOK_EXIT_FAILED=()

# WWW configuration retrieval username
#
# Type: string
# Default: ""
WWW_USERNAME=""

# WWW configuration retrieval password
#
# NOTE: if username is defined and if this
#       directive is empty, password will
#       queried from the command prompt.
#
# Type: string
# Default: ""
WWW_PASSWORD=""

# Comment out the following line
# to make this configuration file valid
# die "${TERM_BOLD}You haven't edited default configuration file, have you boy? :)${TERM_RESET}"

# EOF

#####################################################################
#                            FUNCTIONS                              #
#####################################################################

VERSION="2.09";
MYNAME=$(basename $0)
TO_CLEANUP=""
NO_CLEANUP="0"

basedir_get() {
	local me=$(readlink -f "${0}")
	local dir=$(dirname "${me}")
	dir=$(dirname "${dir}")
	
	echo "${dir}"
}

printhelp() {
	cat <<EOF
Usage: $MYNAME [OPTIONS] <config>

This script takes configuration file to combine different sources
to create Java webapplication archive - WAR using maven.

Using hooks, you can run unlimited number of external commands
to alter source tree, giving you unlimited choices to smash webapp
to suit your sick desires.

OPTIONS:
  -c   --config          Loads configuration specified configuration file
       --default-config  Prints default configuration file
       --no-cleanup      Don't remove temporary directories on exit
       --no-deploy       Don't deploy created webapp archive to maven
                         even if configuration says so

  -v   --verbose         Verbose execution
  -q   --quiet           Quiet execution
  -D   --debug           Enables debugging messages
  -T   --time-stamps     Enables timestamps in printed messages
  -V   --version         Prints script version 
  -h   --help            This help message
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

webapp_build_config_write() {
	local file="${1}"
	file_parent_create "${file}" || return 1
	
	msg_info "Writing webapp build configuration to file: ${file}"

	echo "<font color='green'>BUILD HOST</font>: <font color='red'><b>$(hostname)</b></font>" > "${file}"
	echo "<font color='green'>BUILD DATE</font>: <font color='red'><b>$(date +'%Y/%m/%d %H:%M:%S')</b></font>" >> "${file}"
	echo "<font color='green'>BUILD TYPE</font>: <font color='red'><b>${BUILD_TYPE}</b></font>" >> "${file}"
	echo "" >> "${file}"
	
	local var
	local i

	# write scm projects...
	echo "<font color='green'>SCM_PROJECTS</font>: " >> "${file}"
	declare -a var=$(var_as_str "SCM_PROJECTS")
	i=0
	while [ -n "${var[${i}]}" ]; do
		local str="${var[${i}]}"
		str=$(echo "${str}" | perl -pe "s/password=[^\",']+//g")
		echo "    ${str}" >> "${file}"
		i=$((i + 1))
	done
	
	# sync dirs...
	echo "<font color='green'>SYNC_DIRS</font>: " >> "${file}"
	declare -a var=$(var_as_str "SYNC_DIRS")
	i=0
	while [ -n "${var[${i}]}" ]; do
		local str="${var[${i}]}"
		str=$(echo "${str}" | perl -pe "s/password=[^\",']+//g")
		echo "    ${str}" >> "${file}"
		i=$((i + 1))
	done
	
	local hook=""
	for hook in HOOK_{PRE,POST}_{SCM_EXPORT,DIR_SYNC,WAR_CREATE,WAR_DEST_EXTRA}; do
		echo "<font color='green'>${hook}</font>: " >> "${file}"
		declare -a var=$(var_as_str "${hook}")
		i=0
		while [ -n "${var[${i}]}" ]; do
			local str="${var[${i}]}"
			str=$(echo "${str}" | perl -pe "s/password=[^\",']+//g")
			echo "    ${str}" >> "${file}"
			i=$((i + 1))
		done
	done

	# display some maven stuff
	if [ "${BUILD_TYPE}" = "maven" ]; then
		echo "<font color='green'>MVN_OPT</font>: <font color='red'><b>${MVN_OPT}</b></font>" >> "${file}"
		echo "" >> "${file}"
		if [ "${MVN_DEPLOY}" = "1" ]; then
			echo "<font color='green'>MVN_ARTIFACT_ID</font>:      <font color='blue'><b>${MVN_ARTIFACT_ID}</b></font>" >> "${file}"
			echo "<font color='green'>MVN_GROUP_ID</font>:         <font color='blue'><b>${MVN_GROUP_ID}</b></font>" >> "${file}"
			echo "<font color='green'>MVN_ARTIFACT_VERSION</font>: <font color='blue'><b>${MVN_ARTIFACT_VERSION}</b></font>" >> "${file}"
			echo "<font color='green'>MVN_REPOSITORY_URL</font>:   <font color='blue'><b>${MVN_REPOSITORY_URL}</b></font>" >> "${file}"
		fi
	fi

	return 0
}

build_type_func() {
	local fn="webapp_build_${BUILD_TYPE}"
	if type "${fn}" | head -n1 | grep -q ' function'; then
		echo "${fn}"
	else
		echo "webapp_build_unknown"
	fi
}

webapp_build() {
	local dir="${1}"
	
	# should we create data about
	# current build?
	if [ ! -z "${BUILD_SETTINGS}" ]; then
		local file="${dir}/${BUILD_SETTINGS}"
		webapp_build_config_write "${file}" || return 1 
	fi
	
	# run pre create hook
	hook_run "HOOK_PRE_WAR_CREATE" || return 1
	
	# how should the final file be named?
	local webapp_file=$(shell_pattern_resolve "${WAR_ARCHIVE_NAME}")
	local file=$(basename "${webapp_file}")
	file="${WEBAPP_TMP}/${file}"

	# how to build it?
	func=$(build_type_func)
	
	# run webapp build function
	${func} "${dir}" "${file}"
	local rv=$?
	test "${rv}" != "0" -o ! -f "${file}" && return 1

	# run post create hook
	hook_run "HOOK_POST_WAR_CREATE" || return 1

	msg_info "Webapp was built ${TERM_LGREEN}successfully${TERM_RESET}." 
	# webapp was successfully built.
	#msg_info "${TERM_LGREEN}Successfully${TERM_RESET} created webapp archive: ${TERM_YELLOW}${file}${TERM_RESET}"
	
	# put archive name to it's right place...
	war_deploy_local "${file}" "${webapp_file}" || return 1

	# deploy to maven repository...
	war_deploy_mvn "${file}" || return 1

	# this is it!
	return 0
}

webapp_build_mvn() {
	local dir="${1}"
	local final_file="${2}"
	
	maven_clear_opt
	maven_set_opt "${MVN_OPT}"

	# create webapp package...
	msg_info "Running webapp ${TERM_LRED}MAVEN${TERM_RESET} build."
	maven_cmd "${dir}" clean package || return 1
	
	# check for war existence...
	local wars=""
	local f=""
	local n_wars=0
	
	# check for created wars...
	local war_dir="${dir}"
	test ! -z "${MVN_WAR_DIR}" && war_dir="${war_dir}/${MVN_WAR_DIR}"
	war_dir="${war_dir}/target"
	for f in "${war_dir}"/*.war; do
		test -f "${f}" -a -r "${f}" || continue
		n_wars=$((n_wars + 1))
		if [ -z "${wars}" ]; then
			wars="${f}"
		else
			wars="${wars} $f"
		fi
	done

	# check for injuries...
	if [ "${n_wars}" = "0" ]; then
		error_set "No WAR files were created."
		return 1
	fi
	
	if [ "${n_wars}" != "1" ]; then
		error_set "Multiple war files were created; don't know which one to use."
		return 1
	fi
	
	# copy war to desired file
	msg_debug "Copying webapp '${wars}' to final temp file: '${final_file}'."
	if ! cp "${wars}" "${final_file}"; then
		error_set "Unable to copy webapp '${wars}' to final temp file: '${final_file}'."
		return 1
	fi

	msg_info "Maven build was ${TERM_LGREEN}successful.${TERM_RESET}."
	return 0
}

webapp_build_make() {
	local dir="${1}"
	local final_file="${2}"
	local cwd=$(pwd)

	make_clear_opt
	make_set_opt "${MAKE_OPT}"

	# create webapp package...
	msg_info "Running webapp ${TERM_LRED}MAKE${TERM_RESET} build."
	make_cmd "${dir}" || return 1
	archive_create "${dir}" "${final_file}" || return 1
	
	msg_info "Make build was ${TERM_LGREEN}successful.${TERM_RESET}."
	return 0
}

webapp_build_static() {
	local dir="${1}"
	local final_file="${2}"
	local cwd=$(pwd)

	# just create an archive
	msg_info "Running webapp ${TERM_LRED}STATIC${TERM_RESET} build."
	archive_create "${dir}" "${final_file}" || return 1
	msg_info "Static build was ${TERM_LGREEN}successful${TERM_RESET}."

	return 0
}

webapp_build_grunt() {
	local dir="${1}"
	local final_file="${2}"
	local cwd=$(pwd)

	# do we have node_modules dir?
	if [ ! -e "$dir/node_modules" ]; then
		local nm_ok=0
		local d=
		for d in /usr/lib /usr/local/lib "$HOME"; do
			test -d "$d/node_modules" -a -r "$d/node_modules" || continue
			ln -fs "$d/node_modules" "$dir/node_modules" || continue
			msg_verbose "Created node_modules symlink to $dir/node_modules"
			nm_ok=1
			break
		done
		test "$nm_ok" = "1" || msg_warn "Couldn't find node_modules dir on a system."
	fi

	# perform grunt build
	msg_info "Running ${TERM_LRED}GRUNT${TERM_RESET} build."
	( cd "$dir" && grunt build ) || {
		error_set "Grunt build failed."
		return 1
	}

	# check for dist dir...
	test -d "$dir/dist" && ls "$dir/dist/"* >/dev/null 2>&1 || {
		error_set "Grunt build didn't result in non-empty dist directory."
		return 1
	}

	# create archive
	archive_create "${dir}/dist" "${final_file}" || return 1
	msg_info "Grunt build was ${TERM_LGREEN}successful${TERM_RESET}."

	return 0
}

webapp_build_unknown() {
	error_set "Invalid setting \${BUILD_TYPE}: unsupported build type: '${BUILD_TYPE}'."
	return 1
}

war_deploy_local() {
	local src="${1}"
	local dst="${2}"
	
	dst=$(shell_pattern_resolve "${dst}")
	
	file_parent_create "${dst}" || return 1
	msg_info "Deploying webapp archive to local file: ${TERM_BOLD}${dst}${TERM_RESET}"
	if ! cp "${src}" "${dst}"; then
		error_set "Unable to copy webapp archive '${src}' to it's final destination '${dst}'."
		return 1
	fi

	# create LATEST symlink...
	local suffix=$(echo "${dst}" | perl -p -e 's/(.+)\.([a-z\0-9]{3,8})$/$2/g')
	local word_root=$(echo "${dst}" | perl -p -e 's/(.*)-[\w\.]+/$1/g')
	local parent=$(dirname "${dst}")
	local f=$(basename "${dst}")
	local symlink="${word_root}.latest.${suffix}"
	if [ "${f}" != "${symlink}" ]; then
		msg_verbose "Installing symlink: ${symlink} => ${dst}"
		( cd "${parent}" && ln -fs "${f}" "${symlink}" )
	fi

	# distribute it to extra places...
	war_deploy_local_extra "${src}" || return 1

	return 0
}

war_deploy_local_extra() {
	local file="${1}"
	if [ ! -f "${file}" -o ! -r "${file}" ]; then
		error_set "Invalid war file: '${file}'"
		return 1
	fi
	
	# export archive to hooks
	ARCHIVE="${file}"

	hook_run "HOOK_PRE_WAR_DEST_EXTRA"
	local info_str="Dropping webapp archive to additional locations:"
	local info_str_printed=0
	local i=0
	while [ -n "${WAR_DEST_EXTRA[$i]}" ]; do
		local loc="${WAR_DEST_EXTRA[$i]}"
		local dest=""
	
		for dest in $loc; do
			if [ "${info_str_printed}" = "0" ]; then
				msg_info "${info_str}"
				info_str_printed=1
			fi

			dest=$(shell_pattern_resolve "${dest}")
			msg_info "    ${TERM_LBLUE}$dest${TERM_RESET}"
			file_parent_create "${dest}" || return 1

			# do the copy...
			if ! cp -f "${file}" "$dest"; then
				error_set "Unable to copy webapp archive: ${file} => ${dest}"
				return 1
			fi
		done
		i=$((i + 1))
	done
	hook_run "HOOK_POST_WAR_DEST_EXTRA"

	return 0
}

war_deploy_mvn() {
	local file="${1}"

	if [ "${MVN_DEPLOY}" != "1" ]; then
		msg_verbose "Maven repository deploy is disabled, skipping deploy."
		return 0
	fi

	# check extension...
	if ! echo "${file}" | egrep -qi '\.(zip|war|jar)$'; then
		error_set "Unable to deploy file ${file} to maven repository. Only zip/war/jar file types are supported."
		return 1
	fi

	msg_info "Deploying file ${TERM_DGRAY}${file}${TERM_RESET} to Maven repository."
	maven_deploy_file \
		"${file}" \
		"${MVN_GROUP_ID}" \
		"${MVN_ARTIFACT_ID}" \
		"${MVN_ARTIFACT_VERSION}" \
		"${MVN_REPOSITORY_ID}" \
		"${MVN_REPOSITORY_URL}"

	return $?
}

locale_destroy() {
	local var=""
	for var in LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL; do
		export ${var}
		unset ${var}
	done
}

run() {
	msg_info "Starting ${MYNAME} version ${VERSION} on $(hostname) at $(date +%c)"
	local dir=$(tmpdir_create)
	if [ -z "${dir}" -o ! -d "${dir}" -o ! -w "${dir}" ]; then
		error_set "Error creating tmp dir."
		return 1
	fi
	msg_verbose "Created temporary directory: ${TERM_BOLD}${dir}${TERM_RESET}"
	TO_CLEANUP="${TO_CLEANUP} ${dir}"
	
	# create target dir...
	if ! mkdir -p "${dir}/target"; then
		error_set "Unable to create tmp target directory: ${dir}/target"
		return 1
	fi 

	# export dir variable to hooks
	WEBAPP_TMP="${dir}"
	WEBAPP_DIR="${dir}/target"
	local wd="${WEBAPP_DIR}"
	
	# check for variable WAR_ARCHIVE_NAME
	if [ -z "${WAR_ARCHIVE_NAME}" ]; then
		error_set "Empty configuration variable WAR_ARCHIVE_NAME"
		return 0
	fi
	
	if [ "${DIR_SYNC_BEFORE_SCM_EXPORT}" = "1" ]; then
		# sync files from other sources...
		hook_run "HOOK_PRE_DIR_SYNC" || return 1
		dirsync_run "SYNC_DIRS" "${wd}"  || return 1
		hook_run "HOOK_POST_DIR_SYNC" || return 1

		# export everything from SCM
		hook_run "HOOK_PRE_SCM_EXPORT" || return 1
		scm_export "SCM_PROJECTS" "${wd}" || return 1
		hook_run "HOOK_POST_SCM_EXPORT" || return 1
	
	else
		# export everything from SCM
		hook_run "HOOK_PRE_SCM_EXPORT" || return 1
		scm_export "SCM_PROJECTS" "${wd}" || return 1
		hook_run "HOOK_POST_SCM_EXPORT" || return 1
		
		# sync files from other sources...
		hook_run "HOOK_PRE_DIR_SYNC" || return 1
		dirsync_run "SYNC_DIRS" "${wd}"  || return 1
		hook_run "HOOK_POST_DIR_SYNC" || return 1	
	fi

	# build the bloody webapp
	webapp_build "${wd}" || return 1
	
	unset WEBAPP_DIR WEBAPP_TMP ARCHIVE

	# we succeeded!
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
TEMP=$(getopt -o c:DTqvVh --long config:,default-config,no-cleanup,no-deploy,quiet,verbose,debug,time-stamps,version,help -n "$MYNAME" -- "$@")
test "$?" != "0" && die "Command line parsing error."  
eval set -- "$TEMP"
while true; do
	case $1 in
		-c|--config)
			config_load "$2" "${WWW_USERNAME}" "${WWW_PASSWORD}" || my_die
			shift 2
			;;
		--default-config)
			config_default_print 21 510
			exit 0
			;;
		--no-cleanup)
			NO_CLEANUP=1
			shift
			;;
		--no-deploy)
			MVN_DEPLOY=0
			shift;
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
			locale_destroy
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
plugin_load "make" 1
plugin_load "scm" 1
plugin_load "maven" 1
plugin_load "dirsync" 1

# i really love this one
run || my_die

my_exit 0

# EOF
