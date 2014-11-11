#!/bin/sh

#中转服务器需要在/etc/ssh/sshd_config里面加一句：
#GatewayPorts clientspecified，才能远程连接中转服务器，否则只能在中转
#服务器上ssh到目标机器

APP="app-ssh-reverse-keepalive"
PWD="$(cd $(dirname $0) && pwd)"
ROOT="$PWD/.."
CONF="/var/run/$APP.conf"
APP_PID=`cat /var/run/$APP.pid 2>/dev/null` 
DAEMON_PID_FILE="/var/run/$APP.dameon.pid"
DEADLINE_FILE="$ROOT/deadline"

KEY_FILE=$ROOT/conf/ali-ssh-reverse-id_rsa
SSH=$ROOT/bin/ssh
KNOWN_HOSTS=$ROOT/conf/known_hosts
CHECK_INTERVAL=60

get_port()
{
    local netstat="busy"
    local portlist=1

    while [ "$netstat" != "" -o "$portlist" != "0" ] 
    do
        # 可以考虑用/dev/random实现，且是1024以上即可
        local RAN_NUM=`date +%s` 
        local t1=`expr $RAN_NUM % 50000`
        port_result=`expr $t1 + 1030`

        remote_exec "netstat -an | grep $port_result"
        netstat=$exec_result
        remote_exec "cat port.list | grep $port_result | wc -l"
        portlist=$exec_result
    done
}


remote_exec()
{
    exec_result=`$SSH -i $KEY_FILE -o UserKnownHostsFile="$KNOWN_HOSTS" ssh-reverse@115.29.171.150 "$1"`    
}

daemon()
{
    while true
    do
        check_deadline;
        if [ $SHOULD_STOP == 1 ] ; then
            stop;
            return
        fi

        # 更新APP界面
        # cp -r $PWD/is_running.conf $CONF    

        # local prog=`ps | awk '$1=='''$APP_PID''' {print $5}'`
        # if [ "$prog" == "custom" ] ; then

        kill -SIGUSR1 $APP_PID 2>/dev/null
        # fi

        local port=`json4sh.sh get $ROOT/conf/data.json current_port value`

        if [ "$port" != "空" ] ; then
            # 有可能因为路由器重启，断线，或是防火墙重启之类的原因导致
            # 客户端到server的tunnel断开，需要重新再次打洞
            # local port=`cat $PWD/port`

            remote_exec "netstat -an | grep $port"
            local netstat=$exec_result

            if [ "$netstat" == "" ] ; then
                $SSH -i $KEY_FILE -o UserKnownHostsFile="$KNOWN_HOSTS" -g -NfR *:$port:*:22 ssh-reverse@115.29.171.150 2>/dev/null
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

check_deadline()
{
    if [ -f $ROOT/deadline ] ; then
        local deadline=`cat $ROOT/deadline`
        local n=`date +%s`
        # local d=`date -d "$deadline" +%s`
        
        # 超出服务持续时间
        if [ $n -gt $deadline ] ; then
            SHOULD_STOP=1
        fi
    fi

    SHOULD_STOP=0
}

start_for_hour()
{
    local delta_sec
    let "delta_sec = $1 * 3600"

    local cur_sec=`date +%s`
    local deadline_sec=`expr $cur_sec + $delta_sec`

    echo $deadline_sec > $DEADLINE_FILE

    start;
}

start_service()
{

    local port=`json4sh.sh get $ROOT/conf/data.json current_port value`
    if [ $port == "空" ] ; then
        get_port;
        port=$port_result
    fi

    echo "使用PORT:$port"
    $SSH -i $KEY_FILE -o UserKnownHostsFile="$KNOWN_HOSTS" \
        -g -NfR *:$port:*:22 ssh-reverse@115.29.171.150

    if [ $? == 0 ] ; then
        # 在server的端口表文件中保留此port
        $(remote_exec "echo $port >> port.list")
        # 更新APP界面
        cp -r $ROOT/conf/is_running.conf $CONF    
        kill -SIGUSR1 $APP_PID
                
        # 启动守护进程
        $ROOT/sbin/service.sh daemon &
        echo $! > $DAEMON_PID_FILE

        # 设置APP状态为已启动
        appInfo.sh set_status com.modouwifi.$APP ISRUNNING

        json4sh.sh set $ROOT/conf/data.json current_port value $port 
        local pass=`nvram_get 2860 Password`
        json4sh.sh set $ROOT/conf/data.json current_pass value $pass 

        echo start successfully!
    else
        echo start failed!
    fi

}


# start函数的调用场合有两种，一是用户手动点击“开始”按钮
# 另一种是路由器重启后的自动运行（当服务处于开启状态的时候） 
start()
{
    check_deadline;
    if [ $SHOULD_STOP == 1 ] ; then
        stop;
        return
    fi

    if [ ! -f $DAEMON_PID_FILE ] ; then
        # 添加转菊花效果 -- 阿耀 2014-10-29
        updateconf $ROOT/conf/loading.conf -t State -v 0
        loadingapp $ROOT/conf/loading.conf &

        start_service;        
    fi

    # 停止转菊花
    # kill $pid    
    updateconf $ROOT/conf/loading.conf -t State -v 2
}

stop()
{
    local running=`appInfo.sh get_status com.modouwifi.$APP`
    if [ $running == "NOTRUNNING" ] ; then
        exit 1
    fi

    # 在server删除注册过的端口
    local p=`json4sh.sh get $ROOT/conf/data.json current_port value`
    remote_exec "sed -i '/^$p$/d' ~/port.list"

    # kill所有ssh客户端进程
    killall ssh

    # KILL守护进程
    local pid=`cat $DAEMON_PID_FILE`
    kill $pid
    rm $DAEMON_PID_FILE

    # 更新APP界面
    cp -r $ROOT/conf/not_running.conf $CONF    
    kill -SIGUSR1 $APP_PID

    # 删除倒计时文件
    rm $DEADLINE_FILE 2>/dev/null

    # 设置APP状态为未启动
    appInfo.sh set_status com.modouwifi.$APP NOTRUNNING

    json4sh.sh set $ROOT/conf/data.json current_port value "空" 
    local pass=`nvram_get 2860 Password`
    json4sh.sh set $ROOT/conf/data.json current_pass value "未知" 
}

if [ $# -lt 1 ] ; then
    exit 255
fi

case "$1" in
    "start" )
        start;;
    "stop" )
        stop;;
    "daemon" )
        daemon;;
    "start_for_hour" )
        start_for_hour $2 ;;
    * )
        usage ;;
esac
