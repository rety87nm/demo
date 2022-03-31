#!/bin/sh
### BEGIN INIT INFO
# Provides:          distric_lesnoy
# Required-Start:    $remote_fs $syslog 
# Required-Stop:     $remote_fs $syslog
# Should-Start:      postrgresql nginx 
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start fcgi service of district.ani-project.org 
# Description:       This Service is described some district in st. Jelesnodorojnii.
### END INIT INFO

PPATH=/var/www/district_desc/
USER=district_desc
GROUP=district_desc
PIDFILE=/var/run/district_desc/district_desc.pid
DAEMON=./district_desc.fcgi
CONF="/etc/district_desc/"

case "$1" in
	start)
		if [ -f $PIDFILE ]
		then
			echo "$PIDFILE exists, process is already running or crashed"
		else
			if ! [ -d /var/run/district_desc ]; then
				mkdir /var/run/district_desc
			fi
        	chown $USER:$GROUP /var/run/district_desc/

			echo "Starting district_desc Server..."
			start-stop-daemon -d $PPATH --start -p $PIDFILE -c $USER --exec $DAEMON 
		fi
		;;
	stop)
		if [ ! -f $PIDFILE ]
		then
			echo "$PIDFILE does not exist, process is not running"
		else
			PID=$(cat $PIDFILE)
			echo "Stopping ..."
			kill $PID
			while [ -x /proc/${PID} ]
			do
				echo "Waiting for "${PID}"..."
				sleep 1
			done
			rm $PIDFILE
			echo "district_desc Server stopped"
		fi
		;;
	*)
		echo "Please use start or stop as first argument"
		;;
esac

