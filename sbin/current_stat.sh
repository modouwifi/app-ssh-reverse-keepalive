#!/bin/sh

PWD="$(cd $(dirname $0) && pwd)"
ROOT="$PWD/.."

#port=`cat $PWD/port`
deadline=`cat $ROOT/deadline`

n=`date +%s`
let "total_sec=$deadline-$n"
let "day=total_sec/(3600*24)"
let "hour=(total_sec%(3600*24))/3600"
let "min=(total_sec%3600)/60"

port=`json4sh.sh get $ROOT/conf/data.json current_port value`

echo -e "已经打开远程协助,序列号:$port。\n远程协助服务将在$day天$hour小时$min分钟后自动关闭。" | tee > /tmp/app-ssh-reverse-keepalive

#echo -e "已经打开远程协助，服务序列号:$port" > /tmp/app-ssh-reverse
