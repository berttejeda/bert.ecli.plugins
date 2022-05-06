#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
command_name="${script_dir_name}.${script_base_name}"
__docstring__="Search Confluence Wiki using CQL"
numargs=$#
search_term=$*


EXAMPLES="""
e.g.
	* Search for pages with a parent id of 123456, modified after March 20th, 2021
		${command_name} 'type=page and parent=123456 and lastmodified>2021-03-20'
"""

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
Script to search Confluence wiki using Confluence Query Language (CQL)
Read More: https://developer.atlassian.com/server/confluence/advanced-searching-using-cql/
param: [--username|-u <Confluence Username>]
param: [--password|-p <Confluence Password>]
param: [--dry-run|--dry] # Do nothing except echo the commands
param: [--use-cred-mgr]  # See --help usage
param: [--verbose]       # Show informational output
<search term>
"""

# CLI
while (( "$#" )); do
	if [[ "$1" =~ ^--username$|^-u$ ]]; then user_name="${2}";shift;fi
	if [[ "$1" =~ ^--password$|^-p$ ]]; then password="${2}";shift;fi	
  if [[ "$1" =~ ^--base-url$|^-b$ ]]; then baseurl="${2}";shift;fi 
	if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
	if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
	if [[ "$1" =~ ^--help-extended$ ]]; then help_extended=true;fi
	if [[ "$1" =~ ^--verbose$ ]]; then verbose=true;fi
	shift
done 

if [[ (-z $username) && (-z $password) && (-z $help) && (-z $help_extended) ]];then
    echo "Warning: Values for Username and password are empty!"
	echo -e "${USAGE}"
    exit 0
elif [[ ((-z $username) || (-z $password)) && (-z $help) && (-z $help_extended) ]];then
	echo "Warning: Values for either of username or password is empty!"	
	echo -e "${USAGE}"
    exit 0	
elif [[ (-n $help) ]];then
	echo -e "${USAGE}"
    exit 0	
elif [[ (-n $help_extended) ]];then
	echo -e """${USAGE}
Examples:
${EXAMPLES}
"""	
	exit 0	
fi

if [[ -n $verbose ]];then
	echo "Search Term is: ${search_term}"
fi

echo "Searching against ${baseurl?Must provide baseurl (-b)}"
curl -L -s -u "${username}:${password}" -G "${baseurl}/rest/api/content/search" \
--data-urlencode "cql=(${search_term})"