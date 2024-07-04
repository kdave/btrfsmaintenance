#!/bin/bash

# Test is the task: scrub

. $(dirname $(realpath "$0"))/utils

timer_reset "cron"
timer_reset "systemd-timer"
load_config "sysconfig.btrfsmaintenance.testall"

$TESTPATH/btrfs-scrub.sh > ./results/$TESTNAME.full

unload_config
