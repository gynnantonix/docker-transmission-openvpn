#!/bin/bash

LOGFILE=/var/log/transmission.log
TRANSMISSION_HOME=/data/transmission
TRANSMISSION_CONFIG_FILE=$TRANSMISSION_HOME/settings.json

# sets the value of a key in the Transmission settings file
function setConfigKey {
  key=$1
  value=$2
  mv $TRANSMISSION_CONFIG_FILE $TRANSMISSION_CONFIG_FILE.old
  cat $TRANSMISSION_CONFIG_FILE.old | jq ".[\"${key}\"] = \"${value}\"" > $TRANSMISSION_CONFIG_FILE
}

# see https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/ for calling sequence of --up script
tun_dev=$1
tun_mtu=$2
link_mtu=$3
ifconfig_local_ip=$4
ifconfig_remote_ip=$5
call_reason=$6

if [[ -z $call_reason ]] || [[ $call_reason != "init" ]]; then
  echo "transmission/start.sh not called for init. Nothing to do; exiting."
  exit 0
fi

# if transmission's home dir doesn't exist, set it up with the contents of /configs/transmission
home_dir_status=" (exists)"
if [[ ! -d $TRANSMISSION_HOME ]]; then
  echo "Creating ${TRANSMISSION_HOME}"
  mkdir -p $TRANSMISSION_HOME || exit 1
  home_dir_status=" (new)"
  cp --verbose --recursive /configs/transmission/* $TRANSMISSION_HOME
else
  if [[ ! -r $TRANSMISSION_CONFIG_FILE ]]; then
    cp --verbose /configs/transmission/settings.json $TRANSMISSION_CONFIG_FILE || exit 1
  fi

# If transmission-pre-start.sh exists, run it
if [[ -x /scripts/transmission-pre-start.sh ]]
then
   echo "Executing Transmission pre-start script..."
   /scripts/transmission-pre-start.sh "$@" || exit 1
fi

setConfigKey "bind-address-ipv4" $ifconfig_local_ip

# if [[ "combustion" = "$TRANSMISSION_WEB_UI" ]]; then
#   echo "Using Combustion UI, overriding TRANSMISSION_WEB_HOME"
#   export TRANSMISSION_WEB_HOME=/opt/transmission-ui/combustion-release
# fi

# if [[ "kettu" = "$TRANSMISSION_WEB_UI" ]]; then
#   echo "Using Kettu UI, overriding TRANSMISSION_WEB_HOME"
#   export TRANSMISSION_WEB_HOME=/opt/transmission-ui/kettu
# fi

# if [[ "transmission-web-control" = "$TRANSMISSION_WEB_UI" ]]; then
#   echo "Using Transmission Web Control  UI, overriding TRANSMISSION_WEB_HOME"
#   export TRANSMISSION_WEB_HOME=/opt/transmission-ui/transmission-web-control
# fi

if [[ ! -r "/dev/random" ]]; then
  # Avoid "Fatal: no entropy gathering module detected" error
  echo "INFO: /dev/random not found - symlink to /dev/urandom"
  ln -s /dev/urandom /dev/random
fi

. /etc/transmission/userSetup.sh || exit 1

if [[ "true" = "$DROP_DEFAULT_ROUTE" ]]; then
  echo "DROPPING DEFAULT ROUTE"
  ip r del default || exit 1
fi

if [[ -n $DOCKER_LOG ]] && [[ "${DOCKER_LOG^^}" == "FALSE" ]]; then
  LOGFILE=${TRANSMISSION_HOME}/transmission.log
fi

pf_script="(no port forwarding for ${OPENVPN_PROVIDER})"
fi
if [[ "${OPENVPN_PROVIDER^^}" = "PIA" ]]
then
    pf_script="/etc/transmission/updatePort.sh"
elif [[ "${OPENVPN_PROVIDER^^}" = "PERFECTPRIVACY" ]]
then
    pfscript="/etc/transmission/updatePPPort.sh" &
elif [[ "${OPENVPN_PROVIDER^^}" = "PRIVATEVPN" ]]
then
    pf_script="/etc/transmission/updatePrivateVPNPort.sh"
fi

echo <<- ENDSTART
Starting Transmission...
  User name: ${RUN_AS}
  User uid:  $(id -u ${RUN_AS})
  User gid:  $(id -g ${RUN_AS})
  Home dir:  ${TRANSMISSION_HOME}${home_dir_status}
  Logfile:   ${LOGFILE}
  IPv4 Bind Address:   ${ifconfig_local_ip}
  IPv4 Remote Address: ${ifconfig_remote_ip}
  ${pf_script}
ENDSTART

/usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile ${LOGFILE} --log-debug &

if [[ -x pf_script ]]; then
  `${pf_script} ${ifconfig_local_ip}` || exit 1
fi

# If transmission-post-start.sh exists, run it
if [[ -x /scripts/transmission-post-start.sh ]]
then
   echo "Executing Transmission post-start script..."
   /scripts/transmission-post-start.sh "$@" || exit 1
fi
