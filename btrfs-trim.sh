#!/bin/sh
#
# Copyright (c) 2014 SuSE Linux AG, Nuernberg, Germany.
#
# please send bugfixes or comments to http://www.suse.de/feedback.

#
# paranoia settings
#
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

{
OIFS="$IFS"
IFS=:
for MNT in $BTRFS_TRIM_MOUNTPOINTS; do
	IFS="$OIFS"
	if [ $(stat -f --format=%T "$MNT") != "btrfs" ]; then
		echo "Path $MNT is not btrfs, skipping"
		continue
	fi
	echo "Running fstrim on $MNT"
	fstrim "$MNT"
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) sytemd-cat -t "$LOGIDENTIFIER";;
	*) cat;;
esac

exit 0
