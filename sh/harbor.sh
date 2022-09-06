#!/bin/bash

HARBOR_INSTALL_DIR="/mnt/harbor1.10.6/harbor_data/harbor"

check_harbor(){
    local container_count=`docker ps | grep goharbor | wc -l`
    if [ "${container_count}" != 8 ];then
        echo "fail"
    else
        echo "success"
    fi
}

start_harbor(){
    if [ ! -d ${HARBOR_INSTALL_DIR} ];then
        echo "[ERROR]: Directory ${HARBOR_INSTALL_DIR} does not exist!"
        exit 1
    fi
    cd ${HARBOR_INSTALL_DIR}
    docker-compose up -d >/dev/null 2>&1
    if [ $? -ne 0 ];then
        echo "[ERROR]: Failed to start Harbor!"
        exit 1
    fi
    echo "[INFO]: Service Harbor started."
}

stop_harbor(){
    if [ ! -d ${HARBOR_INSTALL_DIR} ];then
        echo "[ERROR]: Directory ${HARBOR_INSTALL_DIR} does not exist!"
        exit 1
    fi
    cd ${HARBOR_INSTALL_DIR}
    docker-compose down >/dev/null 2>&1
    if [ $? -ne 0 ];then
        echo "[ERROR]: Failed to stop Harbor!"
        exit 1
    fi
    echo "[INFO]: Service Harbor stopped."
}

restart_harbor(){
    stop_harbor
    start_harbor
}

check_and_start(){
    local harbor_status=$(check_harbor)
    if [ "${harbor_status}" == "fail" ];then
        echo "[WARN]: Service Harbor status is fail."
        restart_harbor
    else
        echo "[INFO]: Service Harbor has started."
    fi

}

usage(){
    echo -e ""
    echo -e "Usage: $0 [stop|start|status|restart]"
    echo -e ""
    exit 0
}

case $1 in
stop)
    stop_harbor ;;
start)
    check_and_start ;;
status)
    echo "[Status]: $(check_harbor)" ;;
restart)
    restart_harbor ;;
*)
    usage ;;
esac