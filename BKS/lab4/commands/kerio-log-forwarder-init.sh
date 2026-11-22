#!/bin/sh
# Kerio's boxinit lifecycle hook; source files reside on this appliance only.
case "$1" in
 start)
  if test -s /var/run/bks4-log-forwarder.pid && kill -0 "$(cat /var/run/bks4-log-forwarder.pid)" 2>/dev/null; then exit 0; fi
  /usr/bin/perl /usr/local/sbin/bks4-kerio-log-forwarder.pl >/var/log/bks4-forwarder.log 2>&1 &
  echo $! >/var/run/bks4-log-forwarder.pid
  ;;
 stop)
  if test -s /var/run/bks4-log-forwarder.pid; then
   kill "$(cat /var/run/bks4-log-forwarder.pid)" 2>/dev/null || true
   rm -f /var/run/bks4-log-forwarder.pid
  fi
  ;;
 *) echo "Usage: $0 {start|stop}"; exit 1;;
esac
