#!/bin/bash
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.

umask 022
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

if [ -f /etc/sysconfig/btrfsmaintenance ] ; then
    . /etc/sysconfig/btrfsmaintenance
fi

if [ -f /etc/default/btrfsmaintenance ] ; then
    . /etc/default/btrfsmaintenance
fi

LOGIDENTIFIER='btrfs-trim'
. $(dirname $(realpath "$0"))/btrfsmaintenance-functions

{
BTRFS_TRIM_MOUNTPOINTS=$(expand_auto_mountpoint "$BTRFS_TRIM_MOUNTPOINTS")
OIFS="$IFS"
IFS=:
exec 2>&1 # redirect stderr to stdout to catch all output to log destination
for MNT in $BTRFS_TRIM_MOUNTPOINTS; do
	IFS="$OIFS"
	if ! is_btrfs "$MNT"; then
		echo "Path $MNT is not btrfs, skipping"
		continue
	fi
	echo "Running fstrim on $MNT"
	run_task fstrim --verbose "$MNT"
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) systemd-cat -t "$LOGIDENTIFIER";;
	syslog) logger -t "$LOGIDENTIFIER";;
	none) cat >/dev/null;;
	*) cat;;
esac

# Capture exit code from the piped command above and return it
EXIT_STATUS=${PIPESTATUS[0]}
exit $EXIT_STATUS
