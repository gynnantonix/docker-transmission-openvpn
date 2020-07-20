#!/bin/bash
/etc/transmission/start.sh "$@" || exit 1
[[ ! -f /opt/tinyproxy/start.sh ]] || /opt/tinyproxy/start.sh || exit 1
