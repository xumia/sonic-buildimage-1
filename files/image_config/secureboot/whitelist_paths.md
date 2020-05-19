# Configuration Guide
It is the patterns of the relative paths in /host/image-{{hash}}/rw folder.
The patterns will not be used if the Sonic Secure Boot feature is not enabled.
The files that are not in the whitelist will be removed when the Sonic System cold reboot.

### Example to whitelist all the files in a folder
home/.*

### Example to whitelist a file
etc/nsswitch.conf

