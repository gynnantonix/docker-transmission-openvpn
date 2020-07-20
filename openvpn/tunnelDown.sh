#!/bin/bash

/etc/transmission/stop.sh
sleep 1
[[ ! -f /opt/tinyproxy/stop.sh ]] || /opt/tinyproxy/stop.sh

echo "Stopping container" >>/var/log/openvpn.log
kill $(pidof tail)