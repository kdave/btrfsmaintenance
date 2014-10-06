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

OIFS="$IFS"
IFS=:
for MNT in $BTRFS_TRIM_MOUNTPOINTS; do
	IFS="$OIFS"
	if [ $(stat -f --format=%T "$MNT") != "btrfs" ]; then
		echo "Path $MNT is not btrfs, skipping"
		continue
	fi
	echo "Running fstrim on $MNT"
	/usr/sbin/fstrim "$MNT"
done

exit 0
