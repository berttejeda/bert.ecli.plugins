#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
environment_name=${script_dir##*/}
__docstring__="Check project storage quotas for specified Harbor instance"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--username|-u <Harbor Username>]
param: [--password|-p <Harbor Password>]
param: [--dry-run|--dry # Do nothing except echo the underlying commands]
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
  if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
  if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
  if [[ "$1" =~ ^--username$|^-u$ ]]; then user="${2}";shift;fi
  if [[ "$1" =~ ^--password$|^-p$ ]]; then pass="${2}";shift;fi
  if [[ "$1" =~ ^--harbor-url$|^-H$ ]]; then harbor_url="${2}";shift;fi
  shift
done 
if [[ (numargs -lt 1) || (-n $help) ]];then
  echo -e "${USAGE}"    
    exit 0
fi
 
 echo "Querying Harbor at ${harbor_url-?Must specify harbor URL (-H)} for specified tag pattern ..."
 
 mapfile -t used <<< $(curl -u "$user":"$pass" -i -k -X GET "${harbor_url}/api/v2.0/quotas" | grep -A 2 used | grep storage | awk '//{print $2 }')

for (( i=1; i<${#used[@]}; i++ ))
do  
   count=$(echo "${total[$i]} - ${used[$i]}"|bc)
if [[ $count -lt 4000000000 ]] && [[ "${total[$i]}" -ne -1 ]]
then
echo "The ${names[$i]} Harbor project is low on storage"
fi
done

