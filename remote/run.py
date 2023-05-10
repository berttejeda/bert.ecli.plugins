import argparse
from first import first
import getpass
import json
import os
import pandas as pd
import pathlib
import re
import requests
import subprocess
import sys

# Import third-party and custom modules
from ecli.lib.dictutils import DictUtils
from ecli.lib.proc.remote_cli_provider import RemoteCLIProvider
from bertdotconfig import Config
from ecli.lib.logger import Logger

# Setup Logging
logger = Logger().init_logger(__name__)

__docstring__ = 'Sync local files and run local command against specified remote host'
__invocation__ = 'frozen'
__interactive__ = True

class SmartFormatter(argparse.HelpFormatter):

    def _split_lines(self, text, width):
        if text.startswith('R|'):
            return text[2:].splitlines()  
        # this is the RawTextHelpFormatter._split_lines
        return argparse.HelpFormatter._split_lines(self, text, width)

def parse_args():
    parser = argparse.ArgumentParser(
      description="Sync'n Remote-Run Script", 
      formatter_class=SmartFormatter)
    parser.add_argument('--version', action='version', version='%(prog)s remote.run 0.8')
    parser.add_argument('--hostname','-H', help='Remote host')
    parser.add_argument('--port','-p', help='Remote host ssh/sftp port')
    parser.add_argument('--sync-changed-files','-S', action='store_true', default=False)
    parser.add_argument('--username','-u', help='Username to connect as')
    parser.add_argument('--ssh-key','-i', help='ssh key to use for connecting')
    parser.add_argument('--git-username','-gu', help='Git username')
    parser.add_argument('--git-password','-gp', help='Git password')
    parser.add_argument('--remote-path','-r', help='Remote path to sync local files to (defaults to current working directory (CWD))')
    parser.add_argument('--command','---', nargs=argparse.REMAINDER, 
      required=True, 
      help="R|Remote command to execute, e.g.\n"
          "* Run command, specifying remote host (remote path defaults to CWD)\n"
          "  example 1:\n"
          "    ecli remote.run -H myhost.example.local --- ansible-playbook -i localhost, myplaybook.yaml\n"
          "  example 2:\n"
          "    ecli remote.run -H myhost.example.local --- myscript.sh\n"
          "* Specify config file with connection settings\n"
          "  example 1:\n"
          "    ecli remote.run -f remote-config.yaml --- ansible-playbook -i localhost, myplaybook.yaml\n"
          "  example 2:\n"
          "    ecli remote.run -f remote-config.yaml --- myscript.sh\n"
          )
    parser.add_argument('--sftp-config','-f', help="R|Specify settings via ssh/sftp config File, e.g.\n"
         "cat sftp-config.yaml:\n"
          "  host: myremote-host.mydomain.local\n"
          "  user: myusername\n"
          "  port: '22'\n"
          "  remote_path: /home/myusername/my/remote/path\n"
          "  ssh_key_file: ~/.ssh/id_rsa\n"
          "  sync_on: True\n"
          "  sync_no_clobber: True"
          )
    parser.add_argument('--verbose','-v', action='store_true', default=False)
    return parser.parse_known_args()

# CLI Args
args, unknown= parse_args()
# Initialize Values
username = args.username or getpass.getuser()
remote_command = ' '.join(args.command)
git_username = args.git_username
git_password = args.git_password
# Configuration Files
try:
  script_dir = os.path.dirname(os.path.abspath(my.invocation.path))
except NameError:
  script_dir = os.path.dirname(os.path.abspath(__file__))
if not args.sftp_config:
  logger.debug('No config file specified')
config_file = args.sftp_config or os.path.abspath(os.path.join(script_dir, 'remote-config.yaml'))
# Initialize Config
settings = config = Config(config_file_uri=config_file).read()
remote_command = re.sub('[A-Z]:','',remote_command)
remote_command = remote_command.replace('/Users/%s' % username,'~')
remote_command = remote_command.replace('/users/%s' % username,'~')
if settings and any([args.hostname, args.remote_path, args.port,args.ssh_key]):
  logger.error("When specifying a config file, you must not also specify any additional connection details")
  sys.exit(1)
if not settings:
  logger.debug('No config file found (%s)' % config_file)
  hostname = args.hostname
  remote_path = args.remote_path or os.environ['PWD']
  remote_path = re.sub('[A-Z]:','',remote_path)
  remote_path = remote_path.replace('/Users/%s' % username,'~')
  remote_path = remote_path.replace('/users/%s' % username,'~')
  remote_port = args.port or 22
  ssh_key = args.ssh_key or os.path.expanduser('~/.ssh/id_rsa')
  sync_on = args.sync_changed_files or False
  req_params = {
    'hostname': hostname,
    'username': username, 
    'remote_path': remote_path, 
    'remote_port': remote_port, 
    'ssh_key': ssh_key
  }
  req_keys = req_params.keys()
  req_values = [v for k,v in req_params.items()]
  if not all(req_values):
    for key, value in req_params.items():
      if not value:
        logger.error("No config file found or specified and you did not provide a value for '%s'" % key)
    logger.error('Seek --help')
    sys.exit(1)
  settings = {
    'host': hostname, 
    'remote_path': remote_path,
    'port': remote_port, 
    'remote_path': remote_path, 
    'ssh_key_file': ssh_key, 
    'user': username,
    'sync_no_clobber': True,
    'sync_on': sync_on
  }

remote = RemoteCLIProvider(settings)

remote.run(remote_command, 
  git_username=git_username, 
  git_password=git_password
  )