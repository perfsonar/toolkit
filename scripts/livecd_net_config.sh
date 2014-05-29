#!/bin/bash

for i in `ls /sys/class/net/`
do
    if [ "$i" != "lo" ]; then
        # determine if network has interface
        if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${i}" ]; then
            # get mac address
            mac=""
            while read -r line
            do
                if [[ "$line" =~ HWaddr ]]; then
                    mac=`echo $line| sed -e 's/.*HWaddr\s\+\([a-fA-F0-9:]\+\)/\1/'`
                fi
            done < <(/sbin/ifconfig $i)
            
            #create network script with dhcp setup
            echo "DEVICE=\"${i}\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "BOOTPROTO=\"dhcp\""  >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "HWADDR=\"${mac}\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "IPV6INIT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "MTU=\"1500\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "ONBOOT=\"yes\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "TYPE=\"Ethernet\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            echo "NM_CONTROLLED=\"no\"" >> /etc/sysconfig/network-scripts/ifcfg-${i}
            
            #start interface
            /sbin/ifup ${i}
            if [ "$?" != "0" ]; then
                echo "Unable to start interface ${i}"
            fi
        fi
    fi
done 