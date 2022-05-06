#!/usr/bin/env bash

script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
environment_name=${script_dir##*/}
__docstring__="Triggers a Rolling Update apps matching specified pattern"

RESTORE=$(echo -en '\033[0m')
RED=$(echo -en '\033[00;31m')
GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
BLUE=$(echo -en '\033[00;34m')
PURPLE=$(echo -en '\033[00;35m')
CYAN=$(echo -en '\033[00;36m')
LIGHTGRAY=$(echo -en '\033[00;37m')

USAGE="""
Usage: 

* Triggers a Rolling Update for apps matching specified pattern
  ${YELLOW}ecli ${script_dir_name}.${script_base_name}${RESTORE}
  ${YELLOW}param: [--k8s-context|-x <Name of the Kubernetes Context>]${RESTORE}
  ${YELLOW}param: [--k8s-app-pattern|-p <Naming pattern for targeted apps>]${RESTORE}
  ${YELLOW}param: [--list-available-contexts|-lx]${RESTORE}
  ${YELLOW}param: [--dry-run|--dry # Do nothing except echo the underlying commands]${RESTORE}
  

Examples:
  * ${CYAN}List available Kubernetes contexts${RESTORE}
    ${YELLOW}ecli ${script_dir_name}.${script_base_name} -lx${RESTORE}
  * ${CYAN}Trigger a rolling update for all apps named 'some-pod-name' in the test, dev, and qa namespaces for the dev cluster${RESTORE}
    ${YELLOW}ecli ${script_dir_name}.${script_base_name} -x dev-cluster -t statefulset -p '(test|dev|qa)-some-pod-name'${RESTORE}
"""

numargs=$#

# CLI
while (( "$#" )); do
  if [[ "$1" =~ ^--k8s-context$|^-x$ ]]; then k8s_context="${2}";shift;fi
  if [[ "$1" =~ ^--k8s-app-type$|^-t$ ]]; then k8s_app_type="${2}";shift;fi
  if [[ "$1" =~ ^--k8s-app-pattern$|^-p$ ]]; then k8s_app_pattern="${2}";shift;fi
  if [[ "$1" =~ ^--list-available-contexts$|^-lx$ ]]; then list_available_contexts=true;fi
  if [[ "$1" =~ ^--dry-run$|^--dry$ ]]; then action=echo;fi
  if [[ "$1" =~ ^--list-available-clusters$|^-l$ ]]; then list_clusters="true";fi
  if [[ "$1" =~ ^--help$|^--help$ ]]; then help=true;fi
  shift
done 

if [[ (numargs -lt 1) || (-n $help) ]];then
  echo -e "${USAGE}"    
    exit 0
fi

BINARY=kubectl
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
  echo "This function requires $BINARY, install with subcommand pip.install ${BINARY}"
  exit 1
fi

if [[ -n $list_available_contexts ]];then
  KUBECONFIG=$(ls ~/.kube/*.yaml | tr '\n' ':') kubectl config get-contexts
  exit
fi

KUBECONFIG=$(ls ~/.kube/*.yaml | tr '\n' ':') \
kubectl --context ${k8s_context?'Must specify K8s context'} \
get ${k8s_app_type?'Must specify K8s app type'} \
--all-namespaces | \
egrep -i ${k8s_app_pattern?'Must specify K8s app pattern'} | \
while read ns sf rp tt;do 
  if [[ "$rp" =~ ^0 ]];then 
    echo skipping $sf due to 0 replicas
  else
    kubectl -n $ns patch ${k8s_app_type} $sf \
    -p '{"spec":{"template":{"spec":{"terminationGracePeriodSeconds":31}}}}'
  fi
done