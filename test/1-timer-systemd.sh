#!/bin/bash

# Test if the systemd timers are enabled as per the config file

. $(dirname $(realpath "$0"))/utils

load_config "sysconfig.btrfsmaintenance.testall"
timer_setup "systemd-timer"

systemctl list-unit-files | grep btrfs
systemctl --all list-timers | grep btrfs | rev | awk '{print $1" "$2}' | rev

timer_reset "systemd-timer"
systemctl list-unit-files | grep btrfs
systemctl --all list-timers | grep btrfs | rev | awk '{print $1" "$2}' | rev

unload_config
