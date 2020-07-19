#!/bin/bash

#Network check
# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks,
# therefore we use this script to catch error code 2
HOST=${HEALTH_CHECK_HOST:-google.com}

ping -c 1 $HOST
STATUS=$?
if [[ ${STATUS} -ne 0 ]]
then
    echo "Network is down" 1>&2
    exit 1
fi

echo "Network is up"

#Service check
#Expected output is 2 for both checks, 1 for process and 1 for grep
OPENVPN=$(pgrep openvpn | wc -l )
TRANSMISSION=$(pgrep transmission | wc -l)

if [[ ${OPENVPN} -ne 1 ]]
then
	echo "Openvpn process not running" 1>&2
	exit 1
fi
if [[ ${TRANSMISSION} -ne 1 ]]
then
	echo "transmission-daemon process not running" 1>&2
	exit 1
fi

echo "Openvpn and transmission-daemon processes are running"
exit 0
