#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
environment_name=${script_dir##*/}

__docstring__="Add 'latest' tag to specified application matching specified tag "

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--username|-u <Harbor Username>]
param: [--password|-p <Harbor Password>]
param: [--harbor-url|-h <Harbor URL>]
param: [--harbor-project|-r <Harbor Project Name>]
param: [--application|-a <Application Name>]
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
  if [[ "$1" =~ ^--harbor-project$|^-r$ ]]; then harbor_project="${2}";shift;fi
  if [[ "$1" =~ ^--application$|^-a$ ]]; then application="${2}";shift;fi
  if [[ "$1" =~ ^--image-tag$|^-t$ ]]; then tag_search="${2}";shift;fi
  shift
done

if [[ (numargs -lt 1) || (-n $help) ]];then
  echo -e "${USAGE}"    
    exit 0
fi
 
echo "Querying Harbor URL: ${harbor_url?Must specify harbor URL (-H)}"

app_ref="${harbor_project?Must specify harbor project name}/${application?Must specify application name}"

# Get the digest for the 'latest' Tag for a given repository
echo "Retrieving 'latest' tag digest for ${app_ref} ..."
sha=$(curl -s "http://${harbor_url}/api/v2.0/projects/${harbor_project}/repositories/${application}/artifacts?q=tags=latest" | jq -r '.[].digest')
if [[ -n $sha ]];then
  # Delete 'latest' tag
  echo "The digest for tag 'latest' for ${app_ref} is ${sha} ..."
  echo -n "Deleting 'latest' tag digest for ${app_ref} ... "
  ${action} curl -s -u "${username}:${password}" -X DELETE "http://${harbor_url}/api/v2.0/projects/${harbor_project}/repositories/${application}/artifacts/${sha}/tags/latest"
  echo "Done"
fi

# Add a tag 'latest' to specified image
if [[ -n $tag_search ]];then
  newest_artifact_name=$(curl -s "http://${harbor_url}/api/v2.0/projects/${harbor_project}/repositories/${application}/artifacts?q=tags=${tag_search}&page_size=100" | jq -r ''' .[].tags | select( . != null ) | sort_by(.push_time) | .[].name ''' | head -1)
else
  newest_artifact_name=$(curl -s "http://${harbor_url}/api/v2.0/projects/${harbor_project}/repositories/${application}/artifacts?q=tags!=latest&page_size=100" | jq -r ''' .[].tags | select( . != null ) | sort_by(.push_time) | .[].name ''' | head -1)
fi

if [[ -n $newest_artifact_name ]];then
  echo -n "Adding 'latest' tag to ${app_ref} with tag ${newest_artifact_name} ... "
  sha=$(curl -s "http://${harbor_url}/api/v2.0/projects/${harbor_project}/repositories/${application}/artifacts?q=tags=${newest_artifact_name}" | jq -r '.[].digest')
  ${action} curl -s -H 'Content-Type: application/json' -u "${username}:${password}" -X POST "http://${harbor_url}/api/v2.0/projects/${harbor_project}/repositories/${application}/artifacts/${sha}/tags" --data-raw '{"name":"latest"}'
  echo "Done"
else
  echo "Couldn't determine target"
fi