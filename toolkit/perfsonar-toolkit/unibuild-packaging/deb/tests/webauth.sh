#!/bin/sh
set -e

USERNAME=autopkgtest
PASSWORD=autopass

htpasswd -b /etc/perfsonar/toolkit/psadmin.htpasswd $USERNAME $PASSWORD 2>&1

systemctl restart apache2

curl -s -k -L https://localhost/toolkit/auth/ --basic --user $USERNAME:$PASSWORD

