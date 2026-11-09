#!/bin/sh
# Container entrypoint (PID 1): config sanity report, then runsvdir under
# a graceful shutdown trap.
#
# This image has no service switches: opendkim is the whole point of the
# container and always starts (runtime control stays available with
# "sv up|down /etc/service/<name>"). A missing or invalid configuration is
# reported here, so it is visible in "docker logs"; the runit service
# checks the config as well ("opendkim -n") and fails visibly in its own
# service log (/data/log/opendkim) instead of crash-looping silently. The
# Alpine package ships an example config that fails this check until real
# config and keys are mounted at /etc/opendkim.
#
# runsvdir exits immediately on SIGTERM without stopping its services, so
# "docker stop" would leave opendkim mid-shutdown (or hard-killed after the
# 10s timeout). The shutdown therefore stops runsvdir FIRST - otherwise
# its 5-second scan would respawn services that are exited below, racing
# with the "sv exit" commands (a lost command stalls until its timeout).
# "sv exit" then stops each service properly (TERM to the service,
# ./finish runs, runsv exits) and waits.
#
# Shutdown order: rsyslog last, so the shutdown messages of the other
# services still reach the log files.
set -u

OPENDKIM_CONF=/etc/opendkim/opendkim.conf

mkdir -p /run/opendkim
if [ ! -f "$OPENDKIM_CONF" ]; then
    echo "opendkim: warning: $OPENDKIM_CONF not found - mount your configuration and DKIM keys at /etc/opendkim (see README)" >&2
elif ! /usr/sbin/opendkim -n -x "$OPENDKIM_CONF" >/dev/null 2>&1; then
    echo "opendkim: warning: $OPENDKIM_CONF is not valid - the service will retry, see /data/log/opendkim for the error" >&2
fi

runsvdir_pid=

shutdown() {
    trap - TERM INT
    if [ -n "$runsvdir_pid" ]; then
        kill -TERM "$runsvdir_pid" 2>/dev/null
        wait "$runsvdir_pid" 2>/dev/null
    fi
    # sv runs multi-service commands in parallel. rsyslog is stopped last
    # so the shutdown messages of the other services are still logged.
    # When adding a service, list it in the first command.
    sv -w7 exit /etc/service/opendkim 2>/dev/null || true
    sv -w7 exit /etc/service/rsyslog 2>/dev/null || true
    exit 0
}
trap shutdown TERM INT

runsvdir -P /etc/service &
runsvdir_pid=$!
wait "$runsvdir_pid"
exit 0