#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
environment_name=${script_dir##*/}
__docstring__="Get Redlined Namespaces for a K8s Cluster"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--cluster-name|-c <Name of the Rancher-Managed K8s Cluster>]
param: [--username|-u <Rancher Username>]
param: [--password|-p <Rancher Password>]
param: [--list-available-clusters|-l]
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
	if [[ "$1" =~ ^--cluster-name$|^-c$ ]]; then cluster_name="${2}";shift;fi
	if [[ "$1" =~ ^--username$|^-u$ ]]; then user_name="${2}";shift;fi
	if [[ "$1" =~ ^--password$|^-p$ ]]; then password="${2}";shift;fi
  if [[ "$1" =~ ^--rancher-url$|^-r$ ]]; then rancher_url="${2}";shift;fi
	if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
	if [[ "$1" =~ ^--list-available-clusters$|^-l$ ]]; then list_clusters="true";fi
	if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
	shift
done 

if [[ (numargs -lt 1) || (-n $help) ]];then
	echo -e "${USAGE}"    
    exit 0
fi

BINARY=jello
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
	echo "This function requires $BINARY, install with subcommand pip.install ${BINARY}"
	exit 1
fi

echo "Requesting auth_token from ${rancher_url?Must specify Rancher URL (-r)}"

auth_token=$(curl -ks "${rancher_url}/v3-public/activeDirectoryProviders/activedirectory?action=login" -H 'content-type: application/json' --data-binary "{\"username\":\"${username}\",\"password\":\"${password}\"}" | jello -r '_["token"]')

if [[ -z $auth_token ]];then
	echo "Got an empty or invalid auth_token for ${cluster_name}"
	exit 1
fi

echo "Retrieving cluster id for ${cluster_name}"

cluster_id=$(curl -sk -H "Authorization: Bearer ${auth_token}" "${rancher_url}/v3/clusters?name=${cluster_name}" | jello -r '_["data"][0].get("id","")')

if [[ -z $cluster_id ]];then
	echo "Got an empty or invalid Cluster ID for ${cluster_name}"
	exit 1
fi

echo "Querying resource quotes and limits for cluster ${cluster_name}"

result=$(curl -sk -H "Authorization: Bearer ${auth_token}" \
"${rancher_url}/k8s/clusters/${cluster_id}/api/v1/resourcequotas")

echo "The following namespaces exhibit over 70% Allocation-To-Limit Ratios across either CPU,Memory, or Pods"

echo "${result}" | jello -r '\
result = []
for data in _["items"]:
  namespace = data.get("metadata",{}).get("namespace")
  quotaname = data.get("metadata",{}).get("name")
  # CPU
  limits_cpu_hard = data.get("status",{}).get("hard",{}).get("limits.cpu")
  limits_cpu_used = data.get("status",{}).get("used",{}).get("limits.cpu")
  if "m" in limits_cpu_hard:
  	limits_cpu_hard = float(limits_cpu_hard.strip("m"))/1024
  if "m" in limits_cpu_used:
  	limits_cpu_used = float(limits_cpu_used.strip("m"))/1024  
  limits_cpu_in_yaml = (float(limits_cpu_used)/.69)/1.5
  limitsCpu_Allocation_Ratio = (float(limits_cpu_used)/float(limits_cpu_hard)) * 100
  # Memory
  limits_mem_hard = data.get("status",{}).get("hard",{}).get("limits.memory")
  limits_mem_used = data.get("status",{}).get("used",{}).get("limits.memory")
  if "Gi" in limits_mem_hard:
  	limits_mem_hard = limits_mem_hard.strip("Gi")
  elif "Mi" in limits_mem_hard:
  	limits_mem_hard = float(limits_mem_hard.strip("Mi"))/1024
  elif "Ki" in limits_mem_hard:
  	limits_mem_hard = (float(limits_mem_hard.strip("Ki"))/1024)/1024
  elif "m" in limits_mem_hard:
    limits_mem_hard = float(limits_mem_hard.strip("m"))/1024
  else:
  	limits_mem_hard = ((float(limits_mem_hard)/1024)/1024)/1024
  if "Gi" in limits_mem_used:
  	limits_mem_used = limits_mem_used.strip("Gi")
  elif "Mi" in limits_mem_used:
  	limits_mem_used = float(limits_mem_used.strip("Mi"))/1024
  elif "Ki" in limits_mem_used:
  	limits_mem_used = (float(limits_mem_used.strip("Ki"))/1024)/1024
  elif "m" in limits_mem_used:
    limits_mem_used = float(limits_mem_used.strip("m"))/1024
  else:
  	limits_mem_used = ((float(limits_mem_used)/1024)/1024)/1024
  limits_mem_in_yaml = (float(limits_mem_used)/.69)/1.5
  limitsMemory_Allocation_Ratio = (float(limits_mem_used)/float(limits_mem_hard)) * 100  
  # Pods
  limits_pod_hard = data.get("status",{}).get("hard",{}).get("pods")
  limits_pod_used = data.get("status",{}).get("used",{}).get("pods")
  limits_pod_in_yaml = (int(limits_pod_used)/.69)/1.5
  limitsPod_Allocation_Ratio = (int(limits_pod_used)/int(limits_pod_hard)) * 100  
  # Booleans
  is_cpu_allocation_gt_70 = limitsCpu_Allocation_Ratio > 70
  is_mem_allocation_gt_70 = limitsMemory_Allocation_Ratio > 70
  is_pod_allocation_gt_70 = limitsPod_Allocation_Ratio > 70
  # Labels
  ## CPU
  cpu_target_label_ok = "limitsCpu OK"
  cpu_target_label_ko = "limitsCpu NOT OK - Must be Greater Than"
  cpu_target_label = cpu_target_label_ko if is_cpu_allocation_gt_70 else cpu_target_label_ok
  ## Mem
  mem_target_label_ok = "limitsMem OK"
  mem_target_label_ko = "limitsMem NOT OK - Must be Greater Than"
  mem_target_label = mem_target_label_ko if is_mem_allocation_gt_70 else mem_target_label_ok  
  ## Pods
  pod_target_label_ok = "limitsPod OK"
  pod_target_label_ko = "limitsPod NOT OK - Must be Greater Than"
  pod_target_label = pod_target_label_ko if is_pod_allocation_gt_70 else pod_target_label_ok    
  if any([is_cpu_allocation_gt_70, is_mem_allocation_gt_70, is_pod_allocation_gt_70]):
	  d = {
	  	"namespace": namespace,
	  	"quotaname": quotaname,
	  	"limitsCpu.hard": limits_cpu_hard,
	  	"limitsCpu.used": limits_cpu_used,
	  	"limitsCpu Allocation Ratio": limitsCpu_Allocation_Ratio,
	  	cpu_target_label: limits_cpu_in_yaml,
	  	"limitsMem.hard": limits_mem_hard,
	  	"limitsMem.used": limits_mem_used,
	  	"limitsMem Allocation Ratio": limitsMemory_Allocation_Ratio,
	  	mem_target_label: limits_mem_in_yaml,
		"limitsPod.hard": limits_pod_hard,
		"limitsPod.used": limits_pod_used,
		"limitsPod Allocation Ratio": limitsPod_Allocation_Ratio,  	  	
		pod_target_label: limits_pod_in_yaml,
	  }
	  result.append(d)
result'