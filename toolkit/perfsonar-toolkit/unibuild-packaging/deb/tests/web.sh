#!/bin/sh
set -e

curl -s -k -L https://localhost/toolkit/ | grep -i 'Grafana'


