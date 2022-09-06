#!/bin/bash

DEFAULT_HOST="pg-stolon-proxy.aps-os.svc.cluster.local"
DEFAULT_PORT="5432"
DEFAULT_USER="triceed"
DEFAULT_PASS="Server2008!"
DEFAULT_DATABASE="postgres"
DEFAULT_DIRECTORY="/mnt/aps/backup/db"
DEFAULT_DATE="$(date +%Y%m%d%H%M%S)"
DEFAULT_LOGDIR="/var/log/backup_databases"
SCRIPT_VERSION="1.0.0"

logger(){
    [ ! -d "${BACKUP_LOGDIR}" ] && mkdir -p ${BACKUP_LOGDIR}
    local logfile="${BACKUP_LOGDIR}/pgbackup-${DEFAULT_DATE}.log"
    local logtype=$1; local msg=$2
    datetime=`date +'%F %H:%M:%S'`
    format1="${datetime}  [line: `caller 0 | awk '{print$1}'`]"
    format2="${logtype}: ${msg}"
    logformat="$format1  $format2"
    echo -e "${logformat}" | tee -a $logfile
}


test_connection(){
    logger INFO "Test database connection..."
    psql postgresql://''${PSQL_USER}'':''${PSQL_PASS}''\@${PSQL_HOST}:${PSQL_PORT}/${DEFAULT_DATABASE} << EOF
\q
EOF
    
    if [ $? -ne 0 ];then
        logger ERROR "Database address ${PSQL_HOST} cannot connect!"
        exit 1
    fi

    logger INFO "Connection successful"
}

check_command(){
    local cmds=(psql pg_dump gzip)
    logger INFO "Check ${cmds[*]} command..."

    for cmd in ${cmds[@]}
    do
        which $cmd >>/dev/null 2>&1
        if [ $? -ne 0 ];then
            logger ERROR "$cmd: command not found!"
            exit 1
        fi
    done
}

postgres_dump(){
    local database=$1
    logger INFO "Dumping database ${database} ..."

    export PGPASSWORD=${PSQL_PASS}
    pg_dump -h ${PSQL_HOST} -p ${PSQL_PORT} -U ${PSQL_USER} ${database} |gzip > ${BACKUP_DIRECTORY}/${DEFAULT_DATE}/${database}.sql.gz
   
    if [ ${PIPESTATUS[0]} -ne 0 -o ${PIPESTATUS[1]} -ne 0 ];then
        logger ERROR "Failed to dump database ${database}!"
        exit 1
    fi

    logger INFO "Database ${database} dump complete"
}

backup_database(){
    local databases=(
        uums_dev
        ApolloConfigDB
        ApolloPortalDB
        datacanvas_aps
        datacanvas_aps_das
        datacanvas_modelRepo
    )
    
    if [ ! -d "${BACKUP_DIRECTORY}/${DEFAULT_DATE}" ];then
        mkdir -p ${BACKUP_DIRECTORY}/${DEFAULT_DATE}
    fi

    for db in ${databases[@]}
    do
        postgres_dump $db
    done

    logger INFO "Databases backed up to ${BACKUP_DIRECTORY}/${DEFAULT_DATE} directory"
}

delete_unreserved_data(){
    local file_type=$1
    local parent_dir="${BACKUP_DIRECTORY}"
    if [ ${RETENTION_DATE} = 10086 ];then
        return
    fi
    logger INFO "Delete old backup data ${RETENTION_DATE} days ago..."
    local deleted_data=`find ${parent_dir}/* -maxdepth 0  -type ${file_type} -mtime +${RETENTION_DATE}`
    if [ "${deleted_data}" = "" ];then
        logger INFO "Old backup data not found."
    else 
        find ${parent_dir}/* -maxdepth 0  -type ${file_type} -mtime +${RETENTION_DATE} -exec rm -rf {} \;
        if [ $? -ne 0 ];then
            logger ERROR "Failed to delete old backup data: {\n${deleted_data}\n}"
            exit 1
        else
            logger INFO "Deleted old backup data: {\n${deleted_data}\n}"
            logger INFO "Clean up old backup data complete"
        fi
    fi
}

restore_database(){
    echo "TODO"
}

backup_mode(){
    check_command
    test_connection
    backup_database
    delete_unreserved_data d
}

restore_mode(){
    check_command
    test_connection
    restore_database
}

help(){

    echo
    echo "Script: $0" 
    echo "Version: ${SCRIPT_VERSION}"
    
    echo "
Description: This script is used to back up the PostgreSQL database."

    echo
    echo "Usage: "
    echo "       `basename $0` [-h][-v][-T operation_type][-H pg_host][-U pg_user]..."
    echo 
    echo "       -h Help"
    echo "       -v Version"
    
    echo "       -D Backup directory. dfault ${DEFAULT_DIRECTORY}"
    echo "       -H PostgreSQL host. dfault ${DEFAULT_HOST}"
    echo "       -L Backup log directory. dfault ${DEFAULT_LOGDIR}"
    echo "       -P PostgreSQL port. default ${DEFAULT_PORT}"
    echo "       -R Retention date. dfault remove none"
    echo "       -T Operation type. [backup/restore] (*)"
    echo "       -U PostgreSQL user. default ${DEFAULT_USER} "
    echo "       -W PostgreSQL password. default ${DEFAULT_PASS}"
    echo 
    echo "       (*) - Must be defined"
    echo 
    echo "Example: `basename $0` -T backup -H localhost -P 5432 -U admin -W 123 -D /tmp/backup -R 10"
    echo 
}


while getopts "D:hH:L:P:R:T:U:vW:" Option
  do
  case $Option in
      h) 
	  help
	  exit 0;;
      
      v)
	  echo 
	  echo " Name: `basename $0`"
	  echo " Version: ${SCRIPT_VERSION}"
	  echo " Description: Backup PostgreSQL database script."
	  echo " Contact: gaoyq@zetyun.com"
	  echo
	  exit 0;;

      D)
      BACKUP_DIRECTORY=$OPTARG;;

      L)
      BACKUP_LOGDIR=$OPTARG;;
    
      R)
      RETENTION_DATE=$OPTARG;;

      T)
      OPERATION_TYPE=$OPTARG;;

      H)
      PSQL_HOST=$OPTARG;;

      P)
      PSQL_PORT=$OPTARG;;

      U)
      PSQL_USER=$OPTARG;;

      W)
      PSQL_PASS=$OPTARG;;
          
  esac
done 
shift $(($OPTIND - 1))


if [ -z $OPERATION_TYPE ]
    then
    echo "Error: The Operation type is not defined!"
    echo
    
    help
    exit 65   
fi

if [ -z $BACKUP_DIRECTORY ];then
    BACKUP_DIRECTORY="${DEFAULT_DIRECTORY}"
fi

if [ -z $RETENTION_DATE ];then
    RETENTION_DATE=10086
fi

if [ -z $BACKUP_LOGDIR ];then
    BACKUP_LOGDIR="${DEFAULT_LOGDIR}"
fi

if [ -z $PSQL_HOST ];then
    PSQL_HOST="${DEFAULT_HOST}"
fi

if [ -z $PSQL_PORT ];then
    PSQL_PORT="${DEFAULT_PORT}"
fi

if [ -z $PSQL_USER ];then
    PSQL_USER="${DEFAULT_USER}"
fi

if [ -z $PSQL_PASS ];then
    PSQL_PASS="${DEFAULT_PASS}"
fi



if [ "${OPERATION_TYPE}" = "backup" ];then
    backup_mode
elif [ "${OPERATION_TYPE}" = "restore" ];then
    restore_mode
else
    logger ERROR "Unknown operation type!"
    echo 

    help
    exit 65
fi

# EOF