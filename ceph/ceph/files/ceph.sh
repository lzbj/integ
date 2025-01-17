#!/bin/bash
#
# Copyright (c) 2023 Wind River Systems, Inc.
#
# SPDX-License-Identifier: Apache-2.0

INITDIR=/etc/init.d
LOGFILE=/var/log/ceph/ceph-init.log
CEPH_FILE=/var/run/.ceph_started

# Get our nodetype
. /etc/platform/platform.conf

# Exit immediately if ceph not configured (i.e. no mon in the config file)
if ! grep -q "mon\." /etc/ceph/ceph.conf
then
    exit 0
fi

logecho ()
{
    echo $1
    date >> ${LOGFILE}
    echo $1 >> ${LOGFILE}
}

start ()
{
    if [[ "$system_type" != "All-in-one" ]] || [[ "$system_mode" != "duplex" ]]; then
        logecho "Starting ceph services..."
        ${INITDIR}/ceph start >> ${LOGFILE} 2>&1
        RC=$?
    else
        # In an AIO-DX configuration SM manages the floating MON and OSDs and pmon manages
        # the ceph-mds process. Here we defer starting all ceph process to allow SM and pmon
        # to start them at the appropriate time.
        RC=0
    fi

    if [ ! -f ${CEPH_FILE} ]; then
        touch ${CEPH_FILE}
    fi
}

stop ()
{
    if [[ "$system_type" == "All-in-one" ]] && [[ "$system_mode" == "simplex" ]]; then
        logecho "Ceph services will continue to run on node"
        exit 0
    fi

    logecho "Stopping ceph services..."

    if [ -f ${CEPH_FILE} ]; then
        rm -f ${CEPH_FILE}
    fi

    ${INITDIR}/ceph stop >> ${LOGFILE} 2>&1
    RC=$?
}

# If system is an AIO the mtcClient will run this script twice
# from 2 locations and this generates some errors.
# So we have to exit the script if is called
# from /etc/services.d/worker in order to be executed once
if [[ "$system_type" == "All-in-one" ]]; then
    dir_path=$(dirname "$(realpath $0)")
    if [[ "$dir_path" == "/etc/services.d/worker" ]]; then
        exit 0
    fi
fi

RC=0

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

logecho "RC was: $RC"
exit $RC
