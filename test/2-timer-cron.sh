#!/bin/bash

# Test if the cron timers are enabled as per the config file

. $(dirname $(realpath "$0"))/utils

load_config "sysconfig.btrfsmaintenance.testall"

timer_setup "cron"
systemctl list-unit-files | grep btrfs
echo daily:
ls /etc/cron.daily | grep btrfs
echo weekly:
ls /etc/cron.weekly| grep btrfs
echo monthly:
ls /etc/cron.monthly | grep btrfs

timer_reset "cron"
systemctl list-unit-files | grep btrfs
ls /etc/cron.daily | grep btrfs
ls /etc/cron.weekly| grep btrfs
ls /etc/cron.monthly | grep btrfs

unload_config
