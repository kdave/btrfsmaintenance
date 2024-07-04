#!/bin/bash

# Test is the task: trim

. $(dirname $(realpath "$0"))/utils

timer_reset "cron"
timer_reset "systemd-timer"
load_config "sysconfig.btrfsmaintenance.testall"

$TESTPATH/btrfs-trim.sh > ./results/$TESTNAME.full

unload_config
