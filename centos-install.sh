#!/bin/sh
install -oroot -groot -m644 sysconfig.btrfsmaintenance /etc/sysconfig/btrfsmaintenance
install -d -oroot -groot -m755 /usr/share/btrfsmaintenance
install -oroot -groot -m755 btrfs-*.sh /usr/share/btrfsmaintenance/
echo "Now edit cron periods and mount points in /etc/sysconfig/btrfsmaintenance then run ./btrfsmaintenance-refresh-cron.sh to update cron symlinks
"      
