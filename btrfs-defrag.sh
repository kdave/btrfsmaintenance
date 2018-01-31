#!/bin/sh
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

LOGIDENTIFIER='btrfs-defrag'
. $(dirname $(realpath $0))/btrfsmaintenance-functions

{
OIFS="$IFS"
IFS=:
exec 2>&1 # redirect stderr to stdout to catch all output to log destination
for P in $BTRFS_DEFRAG_PATHS; do
	IFS="$OIFS"
	if [ $(stat -f --format=%T "$P") != "btrfs" ]; then
		echo "Path $P is not btrfs, skipping"
		continue
	fi

	disk=$(get_disk_name "$P")

	wait_on_lock_dir "$BTRFS_LOCK_DIR/$disk"

	find "$P" -xdev -size "$BTRFS_DEFRAG_MIN_SIZE" -type f \
		-exec btrfs filesystem defrag -t 32m -f $BTRFS_VERBOSITY '{}' \;

	unlock_dir "$BTRFS_LOCK_DIR/$disk"
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) systemd-cat -t "$LOGIDENTIFIER";;
	syslog) logger -t "$LOGIDENTIFIER";;
	none) cat >/dev/null;;
	*) cat;;
esac

exit 0
