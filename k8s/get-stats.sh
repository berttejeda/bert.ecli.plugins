#!/usr/bin/env bash
#TODO: Convert if...else to a switch statement
script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
environment_name=${script_dir##*/}
__docstring__="Get stats of a given Kubernetes cluster via Prometheus metrics"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--cluster-name|-c <Name of the Rancher-Managed K8s Cluster>]
param: [--list-available-clusters|-l] # List Available clusters
param: [--failed-pods|-fp] # List failed pods
param: [--disk-space|-ds] # List disks on high usage
param: [--node-cpu|-cpu] # List nodes with low available cpu
param: [--node-mem|-mem] # List nodes available memory
param: [--redlined-pvc|-pvc] # List pvc's on high usage
param: [--dry-run|--dry] # Do nothing except echo the underlying commands
param: [--greedy-pods|-greedy] # List pods using less than 10% of resources allocated
param: [--total-pods|-pods] # List total pods created by deployments and statefulsets
param: [--total-alerts|-alerts][--time-period|-time] # Get number of alerts over specified time period
"""

numargs=$#

# CLI
while (( "$#" )); do
  if [[ "$1" =~ ^--prometheus-url$|^-r$ ]]; then prometheus_url="${2}";shift;fi
  if [[ "$1" =~ ^--list-available-clusters$|^-l$ ]]; then list_clusters="true";fi
  if [[ "$1" =~ ^--failed-pods$|^-fp$ ]]; then list_failed_pods="true";fi
  if [[ "$1" =~ ^--low-inodes$|^-li$ ]]; then list_low_inodes="true";fi  
  if [[ "$1" =~ ^--down-nodes$|^-dn$ ]]; then list_unavailable_nodes="true";fi
  if [[ "$1" =~ ^--disk-space$|^-ds$ ]]; then list_disk="true";fi 
  if [[ "$1" =~ ^--node-cpu$|^-cpu$ ]]; then list_cpu="true";fi 
  if [[ "$1" =~ ^--node-mem$|^-mem$ ]]; then list_mem="true";fi
  if [[ "$1" =~ ^--greedy-pods$|^-greedy$ ]]; then greedy="true";fi
  if [[ "$1" =~ ^--total-alerts$|^-alerts$ ]]; then total_alerts="true";fi
  if [[ "$1" =~ ^--total-pods$|^-pods$ ]]; then total_pods="true";fi
  if [[ "$1" =~ ^--time-period$|^-time$ ]]; then interval="${2}";shift;fi
  if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
  if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
  shift
done 

if [[ (numargs -lt 1) || (-n $help) ]];then
  echo -e "${USAGE}"    
    exit 0
fi

api_url="${prometheus_url?Must specify Prometheus URL (-r)}/api/v1/query"

if [[ -n $list_failed_pods ]];then
  echo "Retrieving failed pod stats from ${api_url} for cluster ${cluster_name}"
  failed_pods=$(curl -fs -k -s -d 'query=(kube_pod_status_phase{cluster="'$cluster_name'", phase="Failed"} == 1)' "${api_url}" | jq -r '.[]')
  echo -e "${failed_pods}"
fi
if [[ -n $list_low_inodes ]];then
  echo "Retrieving low inode stats from ${api_url} for cluster ${cluster_name}"
  low_inodes=$(curl -fs -k -s -d 'query=(node_filesystem_files_free{mountpoint!~"/var/lib/osd.*",mountpoint=~"/apps|/data|/var.*|/tmp|/opt|/|/boot"} / node_filesystem_files{mountpoint!~"/var/lib/osd.*",mountpoint=~"/apps|/data|/var.*|/tmp|/opt|/|/boot"} * 100 < 10)' "${api_url}" | jq -r '.[]')
  echo -e "${low_inodes}"
fi
if [[ -n $list_unavailable_nodes ]];then
  echo "Retrieving node stats from ${api_url} for cluster ${cluster_name}"
  node_down=$(curl -fs -k -s -d 'query=(kube_node_status_condition{cluster="'$cluster_name'", condition="Ready",status="true"} != 1 or kube_node_status_condition{cluster="'$cluster_name'", condition!="Ready",status!="false"} > 0)' "${api_url}" | jq -r '.[]')
  echo -e "${node_down}"
fi
if [[ -n $list_cpu ]];then
  echo "Retrieving cpu stats from ${api_url} for cluster ${cluster_name}"
  low_cpu=$(curl -fs -k -s -d 'query=(100 - (avg by(instance, hostname, app_group) (irate(node_cpu_seconds_total{cluster="'$cluster_name'", mode="idle"}[5m])) * 100) > 90)' "${api_url}" | jq -r '.[]')
  echo -e "${low_cpu}"
fi
if [[ -n $list_mem ]];then
  echo "Retrieving mem stats from ${api_url} for cluster ${cluster_name}"
  low_mem=$(curl -fs -k -s -d 'query=((((node_memory_MemTotal_bytes{cluster="'$cluster_name'", type!="weblogic"} - node_memory_MemFree_bytes{cluster="'$cluster_name'", type!="weblogic"} - node_memory_Cached_bytes{cluster="'$cluster_name'", type!="weblogic"}) / (node_memory_MemTotal_bytes{cluster="'$cluster_name'", type!="weblogic"}) * 100)) > 95)' "${api_url}" | jq -r '.[]')
  echo -e "${low_mem}"
fi
# This retrieves disk stats for all clusters on that prometheus instance
if [[ -n $list_disk ]];then
  echo "Retrieving disk stats from ${api_url} for cluster ${cluster_name}"
  low_disk=$(curl -fs -k -s -d 'query=(node_filesystem_avail_bytes{mountpoint!~"/var/lib/osd.*",mountpoint=~"/apps|/data|/var.*|/tmp|/opt|/|/boot"} / node_filesystem_size_bytes{mountpoint!~"/var/lib/osd.*",mountpoint=~"/apps|/data|/var.*|/tmp|/opt|/|/boot"} * 100 < 5 or wmi_logical_disk_free_bytes{volume=~"C:|D:|E:|F:"} / wmi_logical_disk_size_bytes{volume=~"C:|D:|E:|F:"} * 100 < 10)' "${api_url}" | jq -r '.[]')
  echo -e "${low_disk}"
fi
if [[ -n $greedy ]];then
  echo "Retrieving pods using less than 10% of their request allocated"
  greedy_pods=$(curl -fs -k -s -d 'query=(sum by (pod,namespace)(rate(container_cpu_usage_seconds_total{cluster="'$cluster_name'", image!="", container_name!="POD"}[5m])) / sum by (pod,namespace) (kube_pod_container_resource_requests_cpu_cores{cluster="'$cluster_name'"}) * 100 < 10)' "${api_url}" | jq -r '.[]')
  echo -e "${greedy_pods}"
fi
if [[ -n $total_alerts ]];then
  echo "Get the total number of alerts that went from Pending to Firing during the specified time interval"
  total_alerts=$(curl -fs -k -s -d 'query=(sum(changes(ALERTS_FOR_STATE{cluster="'$cluster_name'"}['$interval'])))' "${api_url}" | jq -r '.[]')
  echo -e "${total_alerts}"
fi
if [[ -n $total_pods ]];then
  echo "Get the total number of pods"
  total=$(curl -fs -k -s -d 'query=(sum(kube_pod_info{cluster="'$cluster_name'"}))' "${api_url}" | jq -r '.[]')
  echo -e "${total}"
  total=$(curl -fs -k -s -d 'query=(sum by (namespace)(kube_pod_info{cluster="'$cluster_name'"}))' "${api_url}" | jq -r '.[]')
  echo -e "${total}"
  echo "Get the total number of pods created by statefulsets"
  total_stateful=$(curl -fs -k -s -d 'query=(sum(kube_statefulset_status_replicas_ready{cluster="'$cluster_name'"}))' "${api_url}" | jq -r '.[]')
  echo -e "${total_stateful}"
  total_stateful=$(curl -fs -k -s -d 'query=(sum by (namespace)(kube_statefulset_status_replicas_ready{cluster="'$cluster_name'"}))' "${api_url}" | jq -r '.[]')
  echo -e "${total_stateful}"
  echo "Get the total number of pods created by deployments"
  total_deployment=$(curl -fs -k -s -d 'query=(sum(kube_deployment_status_replicas_available{cluster="'$cluster_name'"}))' "${api_url}" | jq -r '.[]')  
  echo -e "${total_deployment}"
  total_deployment=$(curl -fs -k -s -d 'query=(sum by (namespace)(kube_deployment_status_replicas_available{cluster="'$cluster_name'"}))' "${api_url}" | jq -r '.[]')  
  echo -e "${total_deployment}"
fi