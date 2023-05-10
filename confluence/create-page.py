#!/usr/bin/env python
# -*- coding: utf-8 -*-

__author__ = 'etejeda'
import argparse
from argparse import RawTextHelpFormatter
try:
    import configparser
except ImportError as e:
     import ConfigParser as configparser
from ecli.lib.dictutils import DictUtils
from bertdotconfig import Config
import json
import os
import getpass
import requests
from requests.auth import HTTPBasicAuth
import sys
import warnings
try:
    import urllib.parse as urllib
except ImportError as e:
     import urllib

# compatibility
python_version_major = sys.version_info.major

# requests stuffs
requests.packages.urllib3.disable_warnings()

# Internals
current_user = getpass.getuser()
config = '~/.{u}.conflutil'.format(u=current_user)

# Messages
msg_Invalid_Credentials = """You did not specify valid credentials
        and a valid [Auth] section was not found in the specified or default configuration file ({c}).
        Proceeding with NO Authentication"""
msg_INVALID_CONFIG = "No valid config file specified and I could not find a default configuration: {c}"
msg_IMPROPER_CONFIG = 'I did find a valid config file but it is improperly formatted: {c}'
msg_NO_CONTENT = 'Although you may have specified a document, there was a problem determining its content'
msg_NO_DOCUMENT = 'You didn''t specify a valid document path (-d option). See usage!'
msg_NO_PAGE_ID = "You didn't specify a PAGE ID"
msg_NO_PAGE_KEY = "You didn't specify a PAGE Key, e.g. VIP"
msg_HTTP_ERROR = 'There was an error updating or creating the specified page: {e}'
msg_RETRV_ERROR = 'Failed in retrieving Confluence object information for "{p}", {msg}'

# Parse Command-line Parameters
parser = argparse.ArgumentParser(
    description='Creates and/or updates a specified confluence page from specified document',
    formatter_class=RawTextHelpFormatter,
    epilog="""Default configuration file is {c}) formatted as:
[Auth]
username = TomTester
password = 123456ABCD

[API]
server = 'www.confluence.example.local',
rest_endpoint = '/rest/api/content/'
""".format(c=config))

parser.add_argument("--config", '-c',
                    help="Manually specify a configuration file instead of default file path (~/.$USERNAME.confluence)")
parser.add_argument("--username", '-u', help="Specify username used in authentication")
parser.add_argument("--password", '-p', help="Specify password used in authentication")
parser.add_argument("--server", '-s', help="Specify the Confluence server, e.g. www.confluence.example.local")
parser.add_argument("--rest-endpoint", '-r',
                    help="Specify the Confluence rest api endpoint, e.g. /confluence/rest/api/content/")
parser.add_argument("--document", '-d', help="Specify the document you'll be pushing up")
parser.add_argument("--page-key", '-key', help="Specify the confluence page key, e.g. VIP")
parser.add_argument("--page-id", '-id', help="Specify the confluence page id")
parser.add_argument("--page-title", '-title', help="Specify the confluence page title")
parameters, args = parser.parse_known_args()


# Catch bad system calls
if not len(sys.argv[1:]) > 0:
    parser.print_help()
    sys.exit(0)

# Content origination
document = parameters.document if parameters.document else None
if not document or not os.path.exists(document):
    print(msg_NO_DOCUMENT)
    parser.print_help()
    print('\n\n' + msg_NO_DOCUMENT)
    sys.exit(0)
else:
    document_content = open(document).read()

# Configuration Files
try:
  script_dir = os.path.dirname(os.path.abspath(my.invocation.path))
except NameError:
  script_dir = os.path.dirname(os.path.abspath(__file__))
config_file = os.path.abspath(os.path.join(script_dir, 'config.yaml'))
# Initialize Config
config = Config(config_file_uri=config_file).read()

# Content origination
document = parameters.document if parameters.document else None
if not document or not os.path.exists(document):
    print(msg_NO_DOCUMENT)
    parser.print_help()
    print('\n\n' + msg_NO_DOCUMENT)
    sys.exit(0)
else:
    document_content = open(document).read()

# Catch specified credentials
if all([parameters.username, parameters.password]) or len(args) >= 2:
    if args:
        username = args[0]
        password = args[1]
    else:
        username = parameters.username
        password = parameters.password
elif not config_has_auth:
    warnings.warn(msg_Invalid_Credentials.format(c=config))

# Catch Config errors
if not any([config_exists, parameters.config]):
    quit(msg_INVALID_CONFIG.format(c=config))
elif not config_is_valid:
    quit(msg_IMPROPER_CONFIG.format(c=config))

# Variables
username = parameters.username if parameters.username else cfg.get('Auth', 'username')
password = parameters.password if parameters.password else cfg.get('Auth', 'password')
page_title = parameters.page_title if parameters.page_title else os.path.basename(document).split('.')[0]
page_title_safe = urllib.quote(page_title, safe='')
safe_password = urllib.quote(password, safe='')
rest_endpoint = parameters.rest_endpoint if parameters.rest_endpoint else cfg.get('API', 'rest_endpoint')
server = parameters.server if parameters.server else cfg.get('API', 'server')
page_id = parameters.page_id if parameters.page_id else None
page_key = parameters.page_key if parameters.page_key else quit(msg_NO_PAGE_KEY)

url_http_get = 'https://{u}:{p}@{s}{r}?space={k}&title={t}'.format(
    u=username,
    p=safe_password,
    s=server,
    r=rest_endpoint,
    k=page_key,
    t=page_title_safe
)

def get_page_data(u=url_http_get):
    headers = {'X-Atlassian-Token': 'no-check', 'content-type': 'application/json'}
    response = requests.get(u, headers=headers, verify=False)
    if not response.status_code == 200:
        error = json.loads(response.text)['message']
        quit(msg_HTTP_ERROR.format(e=error))
    return response


def update_page(content, title=None, **kwargs):
    page = type('obj', (object,), {'type': 'obj_container'})
    try:
        if python_version_major  > 2:
            page_data = get_page_data().json().items()
        else:
            page_data = get_page_data().json().iteritems()
    except Exception as e:
        quit(msg_RETRV_ERROR.format(p=page_title, msg="error was %s" % e))
    [setattr(page, str(k), v) for k, v in page_data]
    if not len(page.results) > 0:
        quit(msg_RETRV_ERROR.format(p=page_title, msg="does this page exist?"))
    page_id = page.results[0]['id']
    page_content_url = page.results[0]['_links']['self']
    page_content_auth_url = page_content_url.replace("https://", "https://%s:%s@" % (username, safe_password))
    page_metadata = get_page_data(page_content_auth_url)
    old_version = int(page_metadata.json()['version']['number'])
    new_version = old_version + 1
    content = content if content else quit(msg_NO_CONTENT)
    title = title if title else page.results[0]['title']
    data = {"id": page_id, "type": "page", "title": title,
            "space": {"key": page_key},
            "body": {"storage": {"value": content, "representation": "wiki"}},
            "version": {"number": str(new_version)}}
    headers = {'X-Atlassian-Token': 'no-check', 'content-type': 'application/json'}
    response = requests.put(page_content_url, headers=headers, data=json.dumps(data),
                            verify=False,auth=HTTPBasicAuth(username, password))
    if not response.status_code == 200:
        try:
            response_message = "\n" + json.loads(response.text)['message']
        except Exception:
            response_message = ""
        error_message = "HTTP Return Code: %s Reason: %s %s" % (response.status_code, response.reason, response_message)
        quit(msg_HTTP_ERROR.format(e=error_message))
    return response.status_code


if __name__ == '__main__':
    result = update_page(document_content)
    if result == 200:
        print("Success: Document Published")
    elif result.startswith("5"):
        print("Fail: Something went wrong, error: {e}".format(e=result))
    sys.exit(result)
