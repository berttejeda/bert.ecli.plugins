# Overview

This plugin can execute a command against a remote host 
while allowing  you a seamless means of ensuring your 
local changes are synchronized agains the same path on the remote,
thus simplifying testing your local changes against a remote host.

# Troubleshooting

## Invalid private key

This error may be due to a bug in the Paramiko package, 
whereby ssh keys generated in a newer format are not processed 
correctly, see 
[Paramiko Invalid key on ed25519 host key · Issue #1517 · paramiko/paramiko](https://github.com/paramiko/paramiko/issues/1517).

The fix is to generate a different key using the older format: 
`sh-keygen -m PEM -t rsa -b 2048 -f id_rsa -N ''` 

You'll have to copy that key to whatever host you're 
targeting of course, e.g. `ssh-copy-id myhost.example.com`
