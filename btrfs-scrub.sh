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

LOGIDENTIFIER='btrfs-scrub'

readonly=
if [ "$BTRFS_SCRUB_READ_ONLY" = "true" ]; then
	readonly=-r
fi

ioprio=
if [ "$BTRFS_SCRUB_PRIORITY" = "normal" ]; then
	# ionice(3) best-effort, level 4
	ioprio="-c 2 -n 4"
fi

{
OIFS="$IFS"
IFS=:
for MNT in $BTRFS_SCRUB_MOUNTPOINTS; do
	IFS="$OIFS"
	echo "Running scrub on $MNT"
	if [ $(stat -f --format=%T "$MNT") != "btrfs" ]; then
		echo "Path $MNT is not btrfs, skipping"
		continue
	fi
	btrfs scrub start -Bd $ioprio $readonly "$MNT"
	if [ "$?" != "0" ]; then
		echo "Scrub cancelled at $MNT"
		exit 1
	fi
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) sytemd-cat -t "$LOGIDENTIFIER";;
	*) cat;;
esac

exit 0
