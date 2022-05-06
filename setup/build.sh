#!/usr/bin/env bash
script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
command_name="${script_dir_name}.${script_base_name}"
environment_name=${script_dir##*/}
__docstring__="Creates InnoSetup Installer"
remote_name=origin
setup_file_path=setup.iss

EXAMPLES="""
e.g.
	* Create the InnoSetup Installer, bumping up major version
		${command_name} release major
	* Create the InnoSetup Installer, bumping up minor version
		${command_name} release minor
	* Create the InnoSetup Installer, bumping up patch version
		${command_name} release patch
	* Update the HISTORY.md change file, bumping up the major version number, starting from git commit f8476d7
		${command_name} history major -s f8476d7
	* Update the HISTORY.md change file, bumping up the major version number, starting from git tag v1.0
		${command_name} history major -s v1.0
	* Update the HISTORY.md change file, bumping up the minor version number, starting from git tag v1.0
		${command_name} history minor -s v1.0
	* Update the HISTORY.md change file, bumping up the patch version number, starting from git tag v1.0
		${command_name} history patch -s v1.0
	* Same as above examples, except instruct to not bump up the any version number
		"" release --no-bump
"""

USAGE="""
Usage: ${command_name}
param: [--innosetup-path|-I] <override_innosetup_installation_path>
param: [--setup-file-path|-S] <override_setup_file_path>
param: [--start-tag-or-commit|-s] <start_tag_or_commit>
param: [--end-tag-or-commit|-s] <end_tag_or_commit>
param: [--remote-name|-r] <git_repo_remote_name>
param: [--username|-u] <git_repo_username>
param: [--password|-p] <git_repo_password>
param: [--dry-run|--dry] <Do nothing except echo the underlying commands>
param: [--no-bump] <Skip incrementing of any version numbers>
param: [--no-installer] <Skip building installer>
param: [--help-extended] <Display Usage Information w/ Examples>
param: [--use-cred-mgr This implicit option
populates the username/password variables from 
the Operating System's Credential Manager
It expects an entry in the credential manager 
for '${script_dir_name}.${script_base_name}'
Note: This must be a Generic Credential for Windows Hosts]
[release|history] <major|minor|patch>
"""

numargs=$#

# CLI
while (( "$#" )); do
	if [[ "$1" =~ ^release$|^history$ ]]; then action=$1;release=$2;shift;fi
	if [[ "$1" =~ ^--innosetup-path$|^-I$ ]]; then innosetupdir=$2;shift;fi
	if [[ "$1" =~ ^--setup-file-path|^-S$ ]]; then setup_file_path=$2;shift;fi
	if [[ "$1" =~ ^--remote-name$|^-r$ ]]; then remote_name=$2;shift;fi
	if [[ "$1" =~ ^--start-tag-or-commit$|^-s$ ]]; then start_tag_or_commit=$2;shift;fi
	if [[ "$1" =~ ^--end-tag-or-commit$|^-e$|^-s$ ]]; then end_tag_or_commit=$2;shift;fi		
	if [[ "$1" =~ ^--no-bump$ ]]; then no_bump=true;fi
	if [[ "$1" =~ ^--no-installer$ ]]; then no_installer=true;fi
	if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
	if [[ "$1" =~ ^--help-extended$ ]]; then help_extended=true;fi
	if [[ "$1" =~ ^--dry$ ]]; then exec_action=echo;fi
	shift
	unmatched_args+="${1} "
done

if [[ (($numargs -lt 1) && (-z $no_bump))   || (-n $help) ]]; then 
	echo -e "${USAGE}"
	exit 0
elif [[ (($numargs -lt 1) && (-z $no_bump)) || (-n $help_extended) ]]; then 
	echo -e """${USAGE}
Examples:
${EXAMPLES}
"""	
	exit 0
fi

if ! test "${setup_file_path}";then
	echo "Could not find ${setup_file_path}"
	echo "Are you in the project root?"
	exit 1
fi

RE='[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([0-9A-Za-z-]*\)'

# Get the Base Release Version from the latest git tag
base=$(git tag 2>/dev/null| tail -n 1)

if [ -z "$base" ];then
  base=0.0.0
fi

if [ -z $no_bump ];then
	MAJOR=`echo $base | sed -e "s#$RE#\1#"`
	MINOR=`echo $base | sed -e "s#$RE#\2#"`
	PATCH=`echo $base | sed -e "s#$RE#\3#"`

	case "$release" in
	major)
	  let MAJOR+=1
	  ;;
	minor)
	  let MINOR+=1
	  ;;
	patch)
	  let PATCH+=1
	  ;;
	esac
	export ecli_VERSION="${MAJOR}.${MINOR}.${PATCH}"
else
	export ecli_VERSION="${base}"
fi

function build() {

	default_innosetupdir="/c/Program Files (x86)/Inno Setup 6"
	innosetupdir="${innosetupdir-${default_innosetupdir}}"


	if [ ! -d "$innosetupdir" ]; then
	    echo "ERROR: Couldn't find innosetup which is needed to build the installer. We suggest you install it using chocolatey. Exiting."
	    exit 1
	fi
	echo "ecli Version is ${ecli_VERSION}"
	
	echo "Building Binary Distribution"

	BINARY=pyinstaller
	if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
		echo "This function requires $BINARY, install with pip install ${BINARY}"
		exit 1
	fi

	pyinstaller -i resources/icons/admin.ico \
	--distpath .dist \
	-n ecli \
	--version-file=version.rc \
	--onefile ecli/cli.py \
	--hidden-import  bs4 \
	--hidden-import first \
	--hidden-import click_plugins  \
  --hidden-import colorama \
	--hidden-import Crypto \
	--hidden-import json \
	--hidden-import lxml \
  --hidden-import requests \
	--hidden-import pandas \
  --hidden-import paramiko \
	--clean 

	if [[ -n $no_installer ]];then
		echo "Detected no_installer flag"
		echo "Skipping InnoSetup Steps"
		exit
	fi

	echo "Building InnoSetup"

	${exec_action} "$innosetupdir/iscc.exe" $PWD/setup.iss || exit 1
	
	existing_tag=$(git tag -l "${ecli_VERSION}")

	if [[ -z $existing_tag ]];then 
		echo "Adding git tag for ${ecli_VERSION}"
		${exec_action} git tag "${ecli_VERSION}";
	fi
}

if [[ $action == "release" ]];then
	build
elif [[ $action == "history" ]];then
    git_branch=$(git rev-parse --abbrev-ref HEAD);
    if [[ -z $start_tag_or_commit ]];then
    	first_commit=$(git log --reverse  --pretty=format:'%h' | head -1)
    fi
    last_commit=$(git log --pretty=format:'%h' -n 1)
    repo_url=$(git config --get remote.${remote_name}.url | sed 's/\.git//' | sed 's/:\/\/.*@/:\/\//');
    if [[ $exec_action != "echo" ]];then
    	changes=$(git log --no-merges ${start_tag_or_commit-${first_commit}}..${end_tag_or_commit-${last_commit}} --format="* %s [%h]($repo_url/commit/%H)" | sed 's/      / /')
    	if [[ -n $changes ]];then
	    	changes_header="## Release $(date +%Y-%m-%d) ${ecli_VERSION}"
	    	change_body="\n${changes_header}\n${changes//\*/-}"
	    	new_content=$(awk -v body="${change_body}" 'NR==4{print body}1' HISTORY.md)
	    	echo -e "${new_content}" | tee HISTORY.md
    	fi
    fi
fi
