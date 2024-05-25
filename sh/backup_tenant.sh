#!/bin/bash

DEFAULT_BACKUP_DIR="/tmp/backup_tenant_and_project"
DEFAULT_NAMESPACE="aps-os"
PROGRAM_VERSION="1.0.3"
ERROR_OPTERROR=65
DEFAULT_DATE="$(date +%Y%m%d%H%M%S)"
DEFAULT_LOGDIR="/var/log/backup_tenant_and_project"

logger(){
    [ ! -d "${BACKUP_LOGDIR}" ] && mkdir -p ${BACKUP_LOGDIR}
    local logfile="${BACKUP_LOGDIR}/${BACKUP_TYPE}-${DEFAULT_DATE}.log"
    local logtype=$1; local msg=$2
    datetime=`date +'%F %H:%M:%S'`
    format1="${datetime}  [line: `caller 0 | awk '{print$1}'`]"
    format2="${logtype}: ${msg}"
    logformat="$format1  $format2"
    echo -e "${logformat}" | tee -a $logfile
}

delete_unreserved_data(){
    local file_type=$1
    local parent_dir="${BACKUP_DIRECTORY}"
    if [ ${RETENTION_DATE} = 10086 ];then
        return
    fi
    logger WARN "Delete old backup data ${RETENTION_DATE} days ago..."
    local deleted_data=`find ${parent_dir}/* -maxdepth 0  -type ${file_type} -mtime +${RETENTION_DATE}`
    if [ "${deleted_data}" = "" ];then
        logger INFO "Old backup data not found."
    else 
        find ${parent_dir}/* -maxdepth 0  -type ${file_type} -mtime +${RETENTION_DATE} -exec rm -rf {} \;
        if [ $? -ne 0 ];then
            logger ERROR "Failed to delete old backup data: {\n${deleted_data}\n}"
            exit 1
        else
            logger WARN "Deleted old backup data: {\n${deleted_data}\n}"
        fi
    fi
}

multi_file_tenant(){
    logger info "Backup all tenants to multiple files."

    local tenant_dir="${BACKUP_DIRECTORY}"
    single_tenant_dir="${tenant_dir}/${DEFAULT_DATE}/tenant"
    mkdir -p ${single_tenant_dir}

    tenant_names=($(kubectl get tenant -n ${BACKUP_NAMESPACE} |awk '{print $1}'|grep -v 'NAME'))
    for tname in ${tenant_names[@]}
    do
        kubectl get tenant $tname -n ${BACKUP_NAMESPACE} -o yaml > ${single_tenant_dir}/$tname.yaml
        if [ $? -ne 0 ];then
            logger ERROR "Failed to get tenant $tname !"
            exit 1 
        fi
    done
    logger INFO "All tenants back up to ${single_tenant_dir} directory."
}

multi_file_project(){
    logger INFO "Backup all projects to multiple files."

    local project_dir="${BACKUP_DIRECTORY}"
    single_project_dir="${project_dir}/${DEFAULT_DATE}/project"
    mkdir -p ${single_project_dir}

    project_names=($(kubectl get project -n ${BACKUP_NAMESPACE} |awk '{print $1}'|grep -v 'NAME'))
    for pname in ${project_names[@]}
    do
        kubectl get project $pname -n ${BACKUP_NAMESPACE} -o yaml > ${single_project_dir}/$pname.yaml
        if [ $? -ne 0 ];then
            logger ERROR "Failed to get project $pname !"
            exit 1
        fi
    done
    logger INFO "All projects back up to ${single_project_dir} directory."
}


single_file_tenant(){
    logger INFO "Backup all tenants to single file."

    local tenant_dir="${BACKUP_DIRECTORY}"
    all_tenant_file="${tenant_dir}/tenants_${DEFAULT_DATE}.yaml"
    kubectl get tenant -n ${BACKUP_NAMESPACE} -o yaml > "${all_tenant_file}"
    if [ $? -ne 0 ];then
        logger ERROR "Failed to get all tenants to yaml file!"
        exit 1
    fi
    logger INFO "Backup all tenants to ${all_tenant_file} file."
}

single_file_project(){
    logger INFO "Backup all projects to single file."

    local project_dir="${BACKUP_DIRECTORY}"
    all_project_file="${project_dir}/projects_${DEFAULT_DATE}.yaml"
    kubectl get project -n ${BACKUP_NAMESPACE} -o yaml > "${all_project_file}"
    if [ $? -ne 0 ];then
        logger ERROR "Failed to get all projects to yaml file!"
        exit 1
    fi
    logger INFO "Backup all projects to ${all_project_file} file."
}


save_tenant(){
    logger INFO "Getting all tenants for namespace ${BACKUP_NAMESPACE}..."

    if [ ! -d "${BACKUP_DIRECTORY}" ];then
        mkdir -p ${BACKUP_DIRECTORY}
    fi

    if [ "$SINGLE_FILE" = "true" ];then
        single_file_tenant
        delete_unreserved_data f
    else
        multi_file_tenant
        delete_unreserved_data d
    fi
 
    logger INFO "Backup tenant complete."
    echo
}

save_project(){
    logger INFO "Getting all projects for namespace ${BACKUP_NAMESPACE}..."
    
    if [ ! -d "${BACKUP_DIRECTORY}" ];then
        mkdir -p ${BACKUP_DIRECTORY}
    fi

    if [ "$SINGLE_FILE" = "true" ];then
        single_file_project
        delete_unreserved_data f
    else
        multi_file_project
        delete_unreserved_data d
    fi
 
    logger INFO "Backup project complete."
    echo
}

create_replica_backup(){
    if [ "${COPY_DIRECTORY}" = "null" ];then
        return
    fi

    which rsync >>/dev/null 2>&1
    if [ $? -ne 0 ];then
        logger ERROR "rsync: command not found!"
        exit 1
    fi
    
    logger INFO "Creating replica directory..."
    BACKUP_DIRECTORY=$(handle_parameters ${BACKUP_DIRECTORY})
    rsync -avz --delete ${BACKUP_DIRECTORY} ${COPY_DIRECTORY}
    if [ $? -ne 0 ];then
        logger WARN "Failed to create replica directory!"
        exit 1
    fi
    logger INFO "Replica ${COPY_DIRECTORY}/${BACKUP_DIRECTORY##*/} created."
    echo
}

# 处理输入路径参数存在多个斜杠的情况
# 例如: 参数/tmp/backup////, 返回/tmp/backup
#
# 处理输入路径参数存在1个斜杠的情况
# BACKUP_DIRECTORY=${BACKUP_DIRECTORY%/}
handle_parameters(){
    local x=$1
    case $x in
        *[!/]*/) x=${x%"${x##*[!/]}"};;
         *[/]) x="/";;
    esac
    echo $x
}


help(){

    echo
    echo "Script: $0" 
    echo "Version: ${PROGRAM_VERSION}"
    
    echo "
Description: This script is used to back up the tenant and project yaml files."

    echo
    echo "Usage: "
    echo "       `basename $0` [-h][-v][-D backup_dir][-S single_file][-T backup_type]..."
    echo 
    echo "       -h Help"
    echo "       -v Version"
    echo "       -C Replica directory. default null"
    echo "       -D Backup directory. default ${DEFAULT_BACKUP_DIR}"
    echo "       -L Backup log directory. default ${DEFAULT_LOGDIR}"
    echo "       -N Backup namespace. default ${DEFAULT_NAMESPACE}"
    echo "       -R Retention date. default remove none"
    echo "       -S Single file. [true/false], default true"
    echo "       -T Backup type. [tenan/project/all] (*)"
    echo 
    echo "       (*) - Must be defined"
    echo 
    echo "Example: `basename $0` -T tenant -D /tmp/backup -S false"
    echo 
}


while getopts "C:D:hL:N:R:S:T:v" Option
  do
  case $Option in
      h) 
	  help
	  exit 0;;
      
      v)
	  echo 
	  echo " Name: `basename $0`"
	  echo " Version: ${PROGRAM_VERSION}"
	  echo " Description: Backup tenant and project yaml files"
	  echo " Contact: gaoyq@zetyun.com"
	  echo
	  exit 0;;

      C)
      COPY_DIRECTORY=$OPTARG;;

      D)
      BACKUP_DIRECTORY=$OPTARG;;

      L)
      BACKUP_LOGDIR=$OPTARG;;
    
      N)
      BACKUP_NAMESPACE=$OPTARG;;

      R)
      RETENTION_DATE=$OPTARG;;

      S)
      SINGLE_FILE=$OPTARG;;

      T)
      BACKUP_TYPE=$OPTARG;;
          
  esac
done 
shift $(($OPTIND - 1))


if [ -z $BACKUP_TYPE ]
    then
    echo "Error: The backup type is not defined!"
    echo
    
    help

    exit $ERROR_OPTERROR   
fi


if [ -z $COPY_DIRECTORY ];then
    COPY_DIRECTORY="null"
fi

if [ -z $BACKUP_DIRECTORY ];then
    BACKUP_DIRECTORY="${DEFAULT_BACKUP_DIR}"
fi

if [ -z $SINGLE_FILE ];then
    SINGLE_FILE="true"
fi

if [ -z $RETENTION_DATE ];then
    RETENTION_DATE=10086
fi

if [ -z $BACKUP_NAMESPACE ];then
    BACKUP_NAMESPACE="${DEFAULT_NAMESPACE}"
fi

if [ -z $BACKUP_LOGDIR ];then
    BACKUP_LOGDIR="${DEFAULT_LOGDIR}"
fi

if [ "${BACKUP_TYPE}" = "tenant" ];then
    save_tenant
    create_replica_backup
elif [ "${BACKUP_TYPE}" = "project" ];then
    save_project
    create_replica_backup
else
    save_tenant
    save_project
    create_replica_backup
fi
