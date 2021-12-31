#!/bin/bash

# Test is the task: Balance

. $(dirname $(realpath "$0"))/utils

timer_reset "cron"
timer_reset "systemd-timer"
load_config "sysconfig.btrfsmaintenance.testall"

$TESTPATH/btrfs-balance.sh > ./results/$TESTNAME.full

cat ./results/$TESTNAME.full | grep -q "Before balance of"
[ $? != 0 ] && echo "Balance did not run"
cat ./results/$TESTNAME.full | grep -q "Done,"
[ $? != 0 ] && echo "Balance did not complete?"

unload_config
