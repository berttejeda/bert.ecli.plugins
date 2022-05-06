#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
__docstring__="Create a git issue branch"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--branch-name|-b <Name of the Git Branch>]
param: --change-context|-c <Name of the change context>
param: --branch-type|-t <Branch Type, e.g. feature, bugfix, hotfix>
param: [--dry-run|--dry # Do nothing except echo the commands]
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
	if [[ "$1" =~ ^--branch-name$|^-b$ ]]; then branch_name="${2}";shift;fi
	if [[ "$1" =~ ^--branch-type$|^-t$ ]]; then branch_type="${2}";shift;fi
	if [[ "$1" =~ ^--branch-context$|^-c$ ]]; then branch_context="${2}";shift;fi
	if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
	if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
	shift
done 

if [[ (numargs -lt 1) || (-n $help) ]];then
	echo -e "${USAGE}"    
    exit 0
fi

dtm=$(date +%Y%m%d/%H%M);
if [[ -z $branch_name ]]; then
    final_branch_name=${username-$USERNAME}/$(git rev-parse --abbrev-ref HEAD)/${branch_type}/${dtm}/${branch_context};
else
    final_branch_name=${username-$USERNAME}/${branch_name-$default_branch_name}/${branch_type}/${dtm}/${branch_context};
fi;
${action-eval} git checkout -b ${final_branch_name}
