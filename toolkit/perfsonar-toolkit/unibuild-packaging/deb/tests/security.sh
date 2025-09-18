#!/bin/sh
set -e

VER=$(iptables -V | awk '{print $2}' | sed 's/^v//')

if dpkg --compare-versions "$VER" ge "1.6.0"; then
  WAIT="-w 10"
else
  WAIT="-w"
fi

for i in 1 2 3 4 5; do
  if iptables $WAIT -nvL | grep -C 10 33434:33634; then
    break
  fi
  sleep 1
done
