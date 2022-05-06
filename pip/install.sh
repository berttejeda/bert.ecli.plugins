#!/usr/bin/env bash
script_dir=${0%/*}
script_name=${0##*/}
script_base_name=${script_name%%.*}
script_dir_name=${script_dir##*/}
command_name="${script_dir_name}.${script_base_name}"
environment_name=${script_dir##*/}
__docstring__="Stub for the pip install command"

USAGE="""
Usage: ${script_dir_name}.${script_base_name}
param: [--use-cred-mgr This implicit option
populates the username/password variables from 
the Operating System's Credential Manager
It expects an entry in the credential manager 
for '${script_dir_name}.${script_base_name}'
Note: This must be a Generic Credential for Windows Hosts]
[options] <package_names>
"""

BINARY=pip
if ! [[ ($(type /usr/{,local/}{,s}bin/${BINARY} 2> /dev/null)) || ($(which $BINARY 2> /dev/null)) ]];then
	echo "This function requires $BINARY"
	exit 1
fi

pip install \
--trusted-host=pypi.org \
--trusted-host=files.pythonhosted.org $@