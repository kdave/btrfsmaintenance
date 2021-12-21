#!/bin/bash

# Test is the task: defrag

. $(dirname $(realpath "$0"))/utils

timer_reset "cron"
timer_reset "systemd-timer"
load_config "sysconfig.btrfsmaintenance.testall"

$TESTPATH/btrfs-defrag.sh > ./results/$TESTNAME.full

unload_config
