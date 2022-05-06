#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}

__docstring__="Query Jenkins for specified user information"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--username|-u <Jenkins Username>]
param: [--password|-p <Jenkins Password>]
param: [--list-plugins|-lp # List Installed Plugins]
param: [--verbose # Show informational output]
param: [--use-cred-mgr This implicit option
populates the username/password environment 
variables from the Operating System's Credential Manager
It expects a entry in the credential manager 
for '${script_dir_name}.${script_base_name}'
Note: This must be a Generic Credential for Windows Hosts]
"""

BINARY=curl
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
  echo "This function requires $BINARY, install with subcommand pip.install ${BINARY}"
  exit 1
fi

BINARY=jq
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
  echo "This function requires $BINARY, install with subcommand pip.install ${BINARY}"
  exit 1
fi

# CLI
while (( "$#" )); do
  if [[ "$1" =~ ^--username$|^-u$ ]]; then username="${2}";shift;fi
  if [[ "$1" =~ ^--password$|^-p$ ]]; then password="${2}";shift;fi
  if [[ "$1" =~ ^--jenkins-url$|^-l$ ]]; then jenkins_url="${2}";shift;fi
  if [[ "$1" =~ ^--list-plugins$|^-lp$ ]]; then list_plugins=true;fi
  if [[ "$1" =~ ^--verbose$ ]]; then verbose=true;fi
  if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
  shift
done 

if [[ (-z $username) && (-z $password) && (-z $help) ]];then
    echo "Warning: Values for Username and password are empty!"
  echo -e "${USAGE}"
    exit 0
elif [[ ((-z $username) || (-z $password)) && (-z $help) ]];then
  echo "Warning: Values for either of username or password is empty!" 
  echo -e "${USAGE}"
    exit 0  
elif [[ (-n $help) ]];then
  echo -e "${USAGE}"
    exit 0
fi

user_query_url="${jenkins_url?Must specify jenkins url (-l)}/pluginManager/api/json?depth=1"

if [[ -n $list_plugins ]]; then
  curl -s "${user_query_url}" --user "${username}:${password}" | jq '.plugins[]|{shortName, version,longName}' -c
fi