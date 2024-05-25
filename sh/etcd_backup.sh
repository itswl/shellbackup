#!/bin/bash

sudo find /opt/apsbackup/etcd -name "snapshot*.db*" -type f -mtime +10 -exec rm {} \;

/usr/local/aps/bin/etcdtools.sh export
