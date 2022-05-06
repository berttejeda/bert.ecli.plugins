#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
environment_name=${script_dir##*/}
__docstring__="Update specified plugin path"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--plugin-path|-p <path to the plugin directory>]
param: [--repo-url|-r <git URL associated with the plugin directory>]
param: [--username|-u <git repo Username>]
param: [--password|-p <git repo Password>]
param: [--use-cred-mgr This implicit option
populates the username/password variables from 
the Operating System's Credential Manager
It expects an entry in the credential manager 
for '${script_dir_name}.${script_base_name}'
Note: This must be a Generic Credential for Windows Hosts]
"""

numargs=$#

# CLI
while (( "$#" )); do
	if [[ "$1" =~ ^--repo-url$|^-r$ ]]; then repo_url="${2}";shift;fi
	if [[ "$1" =~ ^--plugin-path$|^-p$ ]]; then plugin_path="${2}";shift;fi
	if [[ "$1" =~ ^--username$|^-u$ ]]; then user_name="${2}";shift;fi
	if [[ "$1" =~ ^--password$|^-p$ ]]; then password="${2}";shift;fi
	if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
	if [[ "$1" =~ ^--no-prompt$ ]]; then no_prompt=true;fi
	if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
	shift
done

if [[ -n $help ]];then
	echo -e "${USAGE}"    
    exit 0
fi

if [[ -z $plugin_path ]];then
	echo -e "${USAGE}"
	echo -e "\nYou did not specify a plugin path"
	echo "To get a list of plugins paths detected,"
	echo "try running 'ecli plugins.list.paths'"
	echo -e "\nTo update all available plugin paths,"
	echo "try running 'ecli plugins.update.all'"
	exit 1
fi

BINARY=git
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
	echo "This function requires $BINARY, install with pip install $BINARY"
	exit 1
fi

if test -d "${plugin_path}";then
	echo "Found ${plugin_path}"
	if [[ -n $no_prompt ]];then
		answer=yes
	else
		echo "The update operation will clear any local changes you've made"
		echo "to files in the specified plugin path"
	    echo 'Do you want to continue? [yes|y/no|n] '
	    sleep 1
	    read -t 60 answer
	fi
    if [[ ${answer,,} =~ ^y ]];then
		echo "Updating plugins for ${plugin_path}"
		cd "${plugin_path}"
		git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
		git pull
	else
		echo "Cancelled"
		exit 0
	fi
else
	echo "${plugin_path} does not exist ..."
	echo "Attempting to pull plugin repo ..."
	if [[ -z $repo_url ]];then
		echo "Must specify repo url, got:"
		echo "repo_url: ${repo_url}"
		exit 1
	else
		git clone "${repo_url}" "${plugin_path}"
	fi	
fi
