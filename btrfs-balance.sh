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

LOGIDENTIFIER='btrfs-balance'
. $(dirname $(realpath $0))/btrfsmaintenance-functions

{
evaluate_auto_mountpoint BTRFS_BALANCE_MOUNTPOINTS
OIFS="$IFS"
IFS=:
exec 2>&1 # redirect stderr to stdout to catch all output to log destination
for MM in $BTRFS_BALANCE_MOUNTPOINTS; do
	IFS="$OIFS"
	if [ $(stat -f --format=%T "$MM") != "btrfs" ]; then
		echo "Path $MM is not btrfs, skipping"
		continue
	fi
	echo "Before balance of $MM"
	btrfs filesystem df "$MM"
	df -H "$MM"

	if detect_mixed_bg "$MM"; then
		btrfs balance start -musage=0 -dusage=0 "$MM"
		# we use the MUSAGE values for both, supposedly less aggressive
		# values, but as the data and metadata space is shared on
		# mixed-bg this does not lead to the situations we want to
		# prevent when the blockgroups are split (ie. underused
		# blockgroups)
		for BB in $BTRFS_BALANCE_MUSAGE; do
			# quick round to clean up the unused block groups
			btrfs balance start -v -musage=$BB -dusage=$BB "$MM"
		done
	else
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
	fi

	echo "After balance of $MM"
	btrfs filesystem df "$MM"
	df -H "$MM"
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
