#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
baseurl=https://service-now.example.local
__docstring__="Query ServiceNow"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--username|-u <Rancher Username>]
param: [--password|-p <Rancher Password>]
param: [--ticket-numbers|-t <CODE1,CODE2,CODE3,CODENNNN>]
param: [--verbose # Show informational output]
param: [--use-cred-mgr This implicit option
populates the username/password environment 
variables from the Operating System's Credential Manager
It expects a entry in the credential manager 
for '${script_dir_name}.${script_base_name}'
Note: This must be a Generic Credential for Windows Hosts]
"""

BINARY=jello
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
	echo "This function requires $BINARY, install with subcommand pip.install ${BINARY}"
	exit 1
fi

system_fields="number,state,sys_created_by,sys_created_on,variables.slt_application_name,variables.custom_attribute,variables.custom_attribute_2"
group_name="Some%20Group%20Name"
ticket_category="Some%20Catagory%20Name"

# CLI
for arg in "${@}";do
  shift
  if [[ "$arg" =~ '^--username$|^-u$|@The ServiceNow username to authenticate as - required' ]]; then username=$1;continue;fi
  if [[ "$arg" =~ '^--password$|^-p$|@The ServiceNow password to use - required' ]]; then password=$1;continue;fi
  if [[ "$arg" =~ '^--group-name$|^-g$|@The ServiceNow Group Name for filtering ticket results' ]]; then group_name=$1;continue;fi
  if [[ "$arg" =~ '^--ticket-numbers$|^-t$|@Specify ticket numbers explicitly' ]]; then ticket_numbers=$1;continue;fi
  if [[ "$arg" =~ '^--system-fields$|^-f$|@Specify ticket numbers explicitly' ]]; then system_fields=$1;continue;fi
  if [[ "$arg" =~ '^--short$|@Short output' ]]; then short=true;continue;fi
  if [[ "$arg" =~ '^--verbose$|@Verbose logging' ]]; then verbose=true;continue;fi
  if [[ "$arg" =~ '^--dry$|@Dry run, only echo commands' ]]; then PREFIX=echo;continue;fi
  if [[ "$arg" =~ '^--help$|@Show Help' ]]; then help=true;continue;fi
  set -- "$@" "$arg"
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

if [[ -n $verbose ]];then
	echo "Querying $baseurl for Tickets matching criteria"
fi

if [[ -n $ticket_numbers ]];then
  tickets_param="number=$(echo $ticket_numbers | sed s/,/^ORnumber=/g)"
  query="${baseurl}/api/now/table/sc_req_item?&displayvalue=all&sysparm_query=${tickets_param}&sysparm_display_value=true&sysparm_exclude_reference_li&sysparm_fields=${system_fields}"
else
  query="${baseurl}/api/now/table/sc_req_item?&displayvalue=all&sysparm_query=assignment_group.name=${group_name}^state!=-3&cat_item=${ticket_category}&sysparm_fields=${system_fields}"
fi

result=$(curl -s \
"${query}" \
-X GET \
--header 'Accept:application/json' \
--user "${username}:${password}")

if [[ -n $result ]];then
	tickets=$(echo "${result}" | jello -r '[r["number"] for r in _["result"]]' | tail -n +2 | head -n -1)
	n_tickets=$(echo "${tickets}" | wc -l)
	if [[ -n $verbose ]];then
		echo "Found $n_tickets tickets:"
	fi
	if [[ -n $short ]];then
		echo "${tickets}" | tr -d \",
	else
		echo "${result}" | jello -r '_'
	fi
else
	if [[ -n $verbose ]];then
		echo No tickets found
	else
		echo '{}'
	fi
fi