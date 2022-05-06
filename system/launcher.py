import argparse
from ecli.lib.dictutils import DictUtils
import os
from ecli.lib.superduperconfig import SuperDuperConfig 
import sys

__docstring__ = 'Launch System Utilities'
__invocation__ = 'frozen'

def parse_args():
    parser = argparse.ArgumentParser(description="System Utilities Launcher")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--utility-name','-n', help='Name of system utility to launch')
    group.add_argument('--list-available','-l', action='store_true', 
    	help='List available system utilities', 
    	required=False, default=False)
    parser.add_argument('--verbose','-v', action='store_true', required=False, default=False)
    return parser.parse_known_args()

# CLI Args
args, unknown= parse_args()
# Configuration Files
try:
	script_dir = os.path.dirname(os.path.abspath(my.invocation.path))
except NameError:
	script_dir = os.path.dirname(os.path.abspath(__file__))
config_file = os.path.abspath(os.path.join(script_dir, 'launcher.config.yaml'))
# Initialize Config Module
superconf = SuperDuperConfig(config_path=config_file)
# Initialize App Config
config = superconf.load_config()
# Dictutil
dictutil = DictUtils()
system_utilities = dictutil.deep_get(config, 'utilities')
# List
if args.list_available:
    for u in system_utilities.get(sys.platform,[]):
        cmd = system_utilities.get(sys.platform,{}).get(u)
        print('- %s: %s' % (u,cmd))
    sys.exit()
# Launch
utility_name = args.utility_name
launch_command = system_utilities.get(sys.platform,{}).get(args.utility_name)
if launch_command:
	os.system(launch_command)
else:
	sys.exit('No command found for %s' % utility_name)