#!/bin/sh

APP="app-ssh-reverse-keepalive"
PWD="$(cd $(dirname $0) && pwd)"
ROOT="$PWD/.."
CONF="/var/run/$APP.conf"
PID_FILE="/var/run/$APP.pid"
DAEMON_PID_FILE="/var/run/$APP.dameon.pid"

# running=`appInfo.sh get_status com.modouwifi.$APP`

if [ -f $DAEMON_PID_FILE ] ; then
    cp -r $ROOT/conf/is_running.conf $CONF
else
    cp -r $ROOT/conf/not_running.conf $CONF
fi

custom $CONF $ROOT &
echo $! > $PID_FILE
