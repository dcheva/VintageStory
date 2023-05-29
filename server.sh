#!/bin/bash
# /etc/init.d/vintagestory.sh
# version 0.4.2 2016-02-09 (YYYY-MM-DD)
# This shell script launches the game server on linux
#
### BEGIN INIT INFO
# Provides:   vintagestory
# Required-Start: $local_fs $remote_fs screen-cleanup
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    vintagestory server
# Description:    Starts the vintagestory server
### END INIT INFO
#set -x
# Shamelessly adapted from http://minecraft.gamepedia.com/Tutorials/Server_startup_script

#Settings
HISTORY=1024
USERNAME='vintagestory'
VSPATH='/home/vintagestory/server'
DATAPATH='/var/vintagestory/data' 

SCREENNAME='vintagestory_server'
SERVICE="VintagestoryServer.exe"
OPTIONS=""


INVOCATION="mono ${SERVICE} --dataPath ${DATAPATH} ${OPTIONS}"
PGREPTEST="${SERVICE} --dataPath ${DATAPATH}"

#Warning
[ -n "${NO_SUPPORT_MODE}" ] && echo "Warning! You are running in 'NO_SUPPORT_MODE', disabling some requirements checks. Have fun but please avoid to ask for support!"

#Commands
command -v mono-xmltool >/dev/null 2>&1 || [ -n "${NO_SUPPORT_MODE}" ] || { echo "Fatal! I require mono (mono-complete package) but it's not installed.  Aborting." >&2; exit 1; }
command -v mono >/dev/null 2>&1 || { echo "Fatal! I require mono but it's not installed.  Aborting." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Fatal! I require curl but it's not installed.  Aborting." >&2; exit 1; }
command -v wget >/dev/null 2>&1 || { echo "Fatal! I require wget but it's not installed.  Aborting." >&2; exit 1; }
command -v screen >/dev/null 2>&1 || { echo "Fatal! I require screen but it's not installed.  Aborting." >&2; exit 1; }

#Possibly run as user of group vintagestory
unset GROUPNAME
ME=$(whoami)
if [ "${ME}" != "${USERNAME}" ] ; then
  groups "${ME}" | grep -q "${USERNAME}" && { GROUPNAME="${USERNAME}"; USERNAME="${ME}"; }
fi

as_user() {
  if [ "${ME}" = "${USERNAME}" ] ; then
    bash -c "${1}"
    return $?
  else
    su "${USERNAME}" -s /bin/bash -c "${1}"
    return $?
  fi
}

vs_version() {
  instdir="${1}"
  if ! [ -f "${instdir}/${SERVICE}" ] ; then
    echo "Fatal! ${SERVICE} not found. Make sure to set a correct VSPATH and DATA in the server.sh file. Aborting." >&2 
    exit 1
  fi
  if [ ! -d "${DATAPATH}" ] ; then
    mkdir -m 775 -p "${DATAPATH}" >/dev/null 2>&1 || { echo "Fatal! Cannot create new "${DATAPATH}".  Aborting." >&2; exit 1; }
  fi
  if [ "${ME}" != "${USERNAME}" ] ; then
    chown "${USERNAME}:${USERNAME}" -R "${DATAPATH}" >/dev/null 2>&1 || { echo "Fatal! ${ME} failed to adjust data privileges.  Aborting." >&2; exit 1; }
  elif [ -n "${GROUPNAME}" ] ; then
    touch "${DATAPATH}/.${PPID}" >/dev/null 2>&1
    find "${DATAPATH}" -user "${ME}" | xargs chgrp "${GROUPNAME}" > /dev/null 2>&1 || { echo "Fatal! ${ME} failed to adjust data privileges.  Aborting." >&2; exit 1; }
    rm "${DATAPATH}/.${PPID}" >/dev/null 2>&1
  fi  
}


vs_start() {
  vs_version ${VSPATH} # otherwise abort
  if  pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" > /dev/null ; then
    echo "${SERVICE} is already running!"
  else
    cd ${VSPATH}
    echo "Starting ${SERVICE} ..."
    if as_user "cd ${VSPATH} && screen -h ${HISTORY} -dmS ${SCREENNAME} ${INVOCATION}" ; then
      sleep 7
    else
      echo "Warning! Problems with ${SERVICE}! Make sure user ${USERNAME} has read/write access."
    fi
    if [ -n "${NO_SUPPORT_MODE}" ] ; then
	   vs_command "/announce WARNING - ${SERVICE} was started in NO_SUPPORT_MODE" > /dev/null 
    fi
    cd - >/dev/null 2>&1
    if ! vs_status ; then
      echo "Error! User ${USERNAME} could not start ${SERVICE}! Please check ${DATAPATH}/Logs." >&2
      return 1
    else
      return 0
    fi
  fi
}

vs_status() {
  if ! pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" > /dev/null ; then
    echo "${SERVICE} is not running."
    return 1
  elif statusmessage=$(vs_command "/stats") ; then
    sleep 1
    if pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" > /dev/null ; then
      echo "${statusmessage}"
      echo "${SERVICE} is up and running!"
      return 0	
    elif ! pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" > /dev/null ; then
      echo "${SERVICE} is not running."
      return 1
    else
      echo "${statusmessage}"
      echo "${SERVICE} is only partially running (not as expected)."
      return 1
    fi
  else
    echo "${statusmessage}"
    echo "${SERVICE} status is indetermined."
	return 1
  fi
}

vs_stop() {
  if pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" > /dev/null ; then
    echo "Stopping ${SERVICE} ..."
    if as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"SERVER SHUTTING DOWN IN 10 SECONDS. Saving map...\"\015'" ; then
      sleep 10
    else
      echo "Warning! ${USERNAME} encountered problems sending a server shutdown notification."
    fi
    if ! as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"/stop\"\015'" ; then
      echo "Warning! ${USERNAME} encountered problems executing the server stop command."
    fi
    sleep 7
    if pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${SCREENNAME}" > /dev/null ; then
      if ! as_user "screen -p 0 -S ${SCREENNAME} -X quit" ; then
        echo "Warning! ${USERNAME} encountered problems terminating the ${SERVICE} processes."
      fi 
    fi
  else
    echo "${SERVICE} was not running."
    return 0
  fi
  if [ $(pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" -c) = "0" ] ; then
    echo "${SERVICE} is stopped."
    return 0
  else
    echo "Error! ${SERVICE} could not be stopped." >&2
    return 1
  fi
}

vs_command() {
  command="${1}"
  servicelog="${DATAPATH}/Logs/server-main.txt"
  if pgrep -u "${USERNAME}","${GROUPNAME:-root}" -f "${PGREPTEST}" > /dev/null ; then
    touch "${servicelog}" >/dev/null 2>&1
    pre_log_len=$(wc -l "${servicelog}" | awk '{print $1}')
    echo "${SERVICE} process found ... executing command"
    if as_user "screen -p 0 -S ${SCREENNAME} -X eval 'stuff \"/$command\"\015'" ; then
      sleep .1 # assumes that the command will run and print to the log file in less than .1 seconds
      # print output, number of lines computed by arithmetic expansion
      if [ -f "${servicelog}" ] ; then
        tail -n $(( $(wc -l "${servicelog}" | awk '{print $1}') - ${pre_log_len} )) "${servicelog}"
        return 0
      else
        echo "Error! Commmand output could not be read from ${servicelog}." >&2
        return 1
      fi
    else
      echo "Error! ${USERNAME} encountered problems with command execution." >&2
      return 1
    fi
  fi
}

vercomp () {
  if [ "${1}" = "${2}" ] ; then
    return 0
  fi
  # init array by ( list ) execution in a subshell with separator . 
  local IFS=.
  local i ver1=(${1}) ver2=(${2})
  # the numeric operations (( ... )) are not supported by all posix shells
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)) ; do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++)) ; do
    if [ -z "${ver2[i]}" ] ; then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})) ; then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})) ; then
      return 2
    fi
  done
  return 0
}

testvercomp () {
  # ${1} is the value to check (installed version) and ${2} is the comparison reference (latest stable version)
  vercomp ${1} ${2}
  case $? in
    0) op='='
       echo "The installed version is already newest stable version ${2}"
       ;;
    1) op='>'
       echo "The installed version is even newer than the lasted stable version ${2}"
       ;;
    2) op='<'
       echo "The installed version is older than the lasted stable version ${2}"
       ;;
  esac
  # ${3} defines the case (the operator) of test success (script does not terminate)
  if [ "${op}" = "${3}" ]; then
    return 0
  else
    return 1
  fi
}

vs_update () {
  echo "Auto update is disabled because unreliable."
  echo "Personal recommendation: Copy aside the server.sh once, e.g. to the parent folder, then for every update do (assuming your data path is somewhere else):"
  echo "1. ./server.sh stop"
  echo "2. rm -rf *"
  echo "3. wget [server archive link copied from account maanger]"
  echo "4. tar -zxvf [hit tab to get the downloaded file name]"
  echo "5. cp ../server.sh ."
  echo "6. ./server.sh start"
}


vs_setup() {
  read -p "Please confirm setup of basic server environment: user ${1} path ${2:-/home/${1}/server} (y/n) " -n 1 -r ; echo
  if [ "${REPLY,,}" = "y" ] ; then
    USERNAME="${1}"
    VSPATH="${2:-/home/${1}/server}"
	if [ "${ME}" != "${USERNAME}" ] ; then
      if ! getent passwd "${USERNAME}" > /dev/null ; then
        useradd -r -s "/bin/false" -U "${USERNAME}" >/dev/null 2>&1 || { echo "Fatal! User setup failed.  Aborting." >&2; exit 1; }
        echo "Setup new user: $(getent passwd "${USERNAME}")"
      fi
      if ! getent group "${USERNAME}" > /dev/null ; then
        groupadd -r "${USERNAME}" >/dev/null 2>&1 || { echo "Fatal! Group setup failed.  Aborting." >&2; exit 1; }
        echo "Setup new group: $(getent group "${USERNAME}")"
      fi
      if ! [ -d "${VSPATH}" ] ; then
        mkdir -m 775 -p "${VSPATH}" >/dev/null || { echo "Fatal! Server path setup failed.  Aborting." >&2; exit 1; }
        chown "${USERNAME}:${USERNAME}" -R "${VSPATH%/*}" >/dev/null 2>&1 || { echo "Fatal! Server privileges setup failed.  Aborting." >&2; exit 1; }
        echo "Setup new server path: $(ls -ld ${VSPATH})"
      fi
	  if [ ! -d "${DATAPATH%/*}" ] ; then
		mkdir -m 775 -p "${DATAPATH%/*}" >/dev/null || { echo "Fatal! Data path setup failed.  Aborting." >&2; exit 1; }
        chown "${USERNAME}:${USERNAME}" -R "${DATAPATH%/*}" >/dev/null 2>&1 || { echo "Fatal! Data privileges setup failed.  Aborting." >&2; exit 1; }
        echo "Setup new data path: $(ls -ld ${DATAPATH%/*})"
	  fi
    else
      if ! getent group "${USERNAME}" > /dev/null 2>&1 ; then
        echo "Fatal! User ${USERNAME} cannot setup missing group.  Aborting." >&2
        exit 1
      elif ! id -nG | grep "${USERNAME}" > /dev/null 2>&1 ; then
        echo "Fatal! User cannot use existing group ${USERNAME}.  Aborting." >&2
        exit 1
      fi
      if ! [ -d "${VSPATH}" ] ; then
        mkdir -m 775 -p "${VSPATH}"  > /dev/null 2>&1 || { echo "Fatal! Server path setup failed.  Aborting." >&2; exit 1; }
        chgrp "${USERNAME}" -R "${VSPATH}"  > /dev/null 2>&1 || { echo "Fatal! Server privileges setup failed.  Aborting." >&2; exit 1; }
        echo "Setup new server path: $(ls -ld ${VSPATH})"
      fi
      if ! [ -d "${DATAPATH%/*}" ] ; then
        mkdir -m 775 -p "${DATAPATH%/*}"  > /dev/null 2>&1 || { echo "Fatal! Data path setup failed.  Aborting." >&2; exit 1; }
        chgrp "${USERNAME}" -R "${DATAPATH%/*}"  > /dev/null 2>&1 || { echo "Fatal! Data privileges setup failed.  Aborting." >&2; exit 1; }
        echo "Setup new data path: $(ls -ld ${DATAPATH%/*})"
      fi
    fi 
    echo "Basic environment setup finished. Now check server.sh header if all info is correct."
	return 0
  else
	echo "Fatal! Setup for user ${1} cancelled.  Aborting." >&2
	return 1
  fi
}

# version check - result 1 means: current version > reference version
vercomp "$(mono --version | grep 'Mono JIT compiler version ' | cut -f5 -d ' ')" '5.0'
[ $? = 1 ] || [ -n "${NO_SUPPORT_MODE}" ] || { echo "Fatal! I require mono compiler version > 5.0 but it's not installed.  Aborting." >&2; exit 1; } 

#Installation check
unset missing
getent passwd "${USERNAME}" > /dev/null || missing=" user ${USERNAME}"
getent group "${USERNAME}" > /dev/null || missing="${missing} group ${USERNAME}"
[ -d "${VSPATH}" ] || missing="${missing} path ${VSPATH}"
if [ -n "${missing}" ] ; then
  echo "Username, Group or data path missing. Server environment setup needed (create${missing})"
  vs_setup "${USERNAME}"
fi

# main
case "${1}" in
  start)
    vs_start
    exit $?
    ;;
  stop)
    vs_stop
    exit $?
    ;;
  restart)
    vs_stop && vs_start
    exit $?
    ;;
  update)
    vs_update
    exit $?
    ;;
  setup)
    if [ "$(id -u)" = 0 -o "${ME}" = "${2:-${GROUPNAME:-$USERNAME}}" ] ; then
      vs_setup "${2:-${GROUPNAME:-$USERNAME}}" "${3}"
      exit $?
    else
      echo "The setup command is only available for the users root and ${2:-${GROUPNAME:-$USERNAME}}."
      exit 1
    fi
    ;;
  status)
    vs_version "${VSPATH}" # otherwise abort
    echo "Data path is ${DATAPATH}"
    vs_status
    exit $?
    ;;
  command)
    vs_version "${VSPATH}" # otherwise abort
    if [ $# -gt 1 ] ; then
      shift
      vs_command "$*"
      exit $?
    else
      echo "Must specify server command (try 'help'?)"
	  exit 1
    fi
    ;; 
  *)
    echo "Usage: ${0} {start|stop|status|update|restart|setup [\"user name\"] [\"path\"]|command \"server command\"}"
    exit 1
    ;;
esac
 
exit 1
