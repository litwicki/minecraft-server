#!/bin/bash

#Settings
# Service should be unique with no shared words between any other servers running
SERVICE='rsmc-dev'
# Seconds to wait before checking if started
START_WAIT=3
# Seconds to wait before checking if stop
STOP_WAIT=30
# Seconds to wait before restarting (between start/stop)
RESTART_WAIT=3
# Seconds to wait after notice server is shutting down
STOP_DELAY=10
EXECUTABLE='minecraft_server.jar'
OPTIONS='nogui'
USERNAME='rsmc'
WORLD='world'
MCPATH='/srv/minecraft/dev.rsmc.io'
BACKUPPATH='/media/backup/minecraft/dev.rsmc.io'
MAXHEAP=8196
MINHEAP=2048
HISTORY=1024
CPU_COUNT=4
JAVA='/usr/lib/jvm/java-7-openjdk/jre/bin/java -classpath /usr/lib/jvm/java-7-openjdk/jre/lib/*:.'
INVOCATION="$JAVA -Xmx${MAXHEAP}M -Xms${MINHEAP}M \
-XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT \
-XX:+AggressiveOpts -Dfml.queryResult=confirm -jar $EXECUTABLE $OPTIONS"

ME=`whoami`
as_user() {
  if [ $ME == $USERNAME ] ; then
    bash -c "$1"
  else
    sudo su - $USERNAME -c "$1"
  fi
}

mc_start() {
  if as_user "screen -ls | grep $SERVICE" > /dev/null
  then
    echo "$SERVICE is already running!"
  else
    echo "Starting $SERVICE..."
    cd $MCPATH
    as_user "cd $MCPATH && screen -h $HISTORY -dmS $SERVICE $INVOCATION"
    echo "Waiting $START_WAIT seconds before checking if $SERVICE is running..."
    sleep $START_WAIT
    if as_user "screen -ls | grep $SERVICE" > /dev/null
    then
      echo "$SERVICE is now running."
    else
      echo "Error! Could not start $SERVICE!"
    fi
  fi
}

mc_saveoff() {
  if as_user "screen -ls | grep $SERVICE" > /dev/null
  then
    echo "$SERVICE is running... suspending saves"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"say World saving paused.\"\015'"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"save-off\"\015'"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"save-all\"\015'"
    sleep 10
  else
    echo "$SERVICE is not running. Not suspending saves."
  fi
}

mc_saveon() {
  if as_user "screen -ls | grep $SERVICE" > /dev/null
  then
    echo "$SERVICE is running... re-enabling saves"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"save-on\"\015'"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"say World saving resumed.\"\015'"
  else
    echo "$SERVICE is not running. Not resuming saves."
  fi
}

mc_stop() {
  if as_user "screen -ls | grep $SERVICE" > /dev/null
  then
    echo "Notifying users $SERVICE is stopping and then waiting $STOP_DELAY seconds..."
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"say Server shutting download in $STOP_DELAY seconds. Saving map...\"\015'"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"save-all\"\015'"
    sleep $STOP_DELAY
    echo "Stopping $SERVICE..."
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"stop\"\015'"
    echo "Waiting $STOP_WAIT seconds before checking if $SERVICE is stopped..."
    sleep $STOP_WAIT
  else
    echo "$SERVICE was not running."
  fi
  if as_user "screen -ls | grep $SERVICE" > /dev/null
  then
    echo "Error! $SERVICE could not be stopped."
  else
    echo "$SERVICE is stopped."
  fi
}

mc_backup() {
   mc_saveoff
   
   NOW=`date "+%Y-%m-%d_%Hh%M"`
   BACKUP_FILE="$BACKUPPATH/${WORLD}_${NOW}.tar"
   echo "Backing up minecraft world..."
   as_user "tar -C \"$MCPATH\" -cf \"$BACKUP_FILE\" $WORLD"

   echo "Backing up $SERVICE"
   as_user "tar -C \"$MCPATH\" -rf \"$BACKUP_FILE\" $SERVICE"

   mc_saveon

   echo "Compressing backup..."
   as_user "gzip -f \"$BACKUP_FILE\""
   echo "Done."
}

mc_command() {
  command="$1";
  if as_user "screen -ls | grep $SERVICE" > /dev/null
  then
    pre_log_len=`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`
    echo "$SERVICE is running... executing command"
    as_user "screen -p 0 -S $SERVICE -X eval 'stuff \"$command\"\015'"
    sleep .1 # assumes that the command will run and print to the log file in less than .1 seconds
    # print output
    tail -n $[`wc -l "$MCPATH/logs/latest.log" | awk '{print $1}'`-$pre_log_len] "$MCPATH/logs/latest.log"
  fi
}

mc_attach() {
  as_user "screen -R $SERVICE"
}

#Start-Stop here
case "$1" in
  start)
    mc_start
    ;;
  stop)
    mc_stop
    ;;
  restart)
    mc_stop
    echo "Waiting $RESTART_WAIT before restarting..."
    sleep $RESTART_WAIT
    mc_start
    ;;
  backup)
    mc_backup
    ;;
  attach)
    mc_attach
    ;;
  status)
    if as_user "screen -ls | grep $SERVICE" > /dev/null
    then
      echo "$SERVICE is running."
    else
      echo "$SERVICE is not running."
    fi
    ;;
  command)
    if [ $# -gt 1 ]; then
      shift
      mc_command "$*"
    else
      echo "Must specify server command (try 'help'?)"
    fi
    ;;
  *)
  echo "Usage: $0 {start|stop|backup|status|restart|attach|command \"server command\"}"
  exit 1
  ;;
esac

exit 0