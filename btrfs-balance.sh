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

LOGIDENTIFIER='btrfs-balance'

{
OIFS="$IFS"
IFS=:
for MM in $BTRFS_BALANCE_MOUNTPOINTS; do
	IFS="$OIFS"
	if [ $(stat -f --format=%T "$MM") != "btrfs" ]; then
		echo "Path $MM is not btrfs, skipping"
		continue
	fi
	echo "Before balance of $MM"
	btrfs filesystem df "$MM"
	df -H "$MM"
	btrfs balance start -dusage=0 "$MM"
	for BB in $BTRFS_BALANCE_DUSAGE; do
		# quick round to clean up the unused block groups
		btrfs balance start -v -dusage=$BB "$MM"
	done
	btrfs balance start -musage=0 "$MM"
	for BB in $BTRFS_BALANCE_MUSAGE; do
		# quick round to clean up the unused block groups
		btrfs balance start -v -musage="$BB" "$MM"
	done
	echo "After balance of $MM"
	btrfs filesystem df "$MM"
	df -H "$MM"
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) sytemd-cat -t "$LOGIDENTIFIER";;
	*) cat;;
esac

exit 0
