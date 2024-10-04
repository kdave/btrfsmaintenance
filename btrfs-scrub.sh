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

LOGIDENTIFIER='btrfs-scrub'
. $(dirname $(realpath "$0"))/btrfsmaintenance-functions

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
BTRFS_SCRUB_MOUNTPOINTS=$(expand_auto_mountpoint "$BTRFS_SCRUB_MOUNTPOINTS")
OIFS="$IFS"
IFS=:
exec 2>&1 # redirect stderr to stdout to catch all output to log destination
for MNT in $BTRFS_SCRUB_MOUNTPOINTS; do
	IFS="$OIFS"
	echo "Running scrub on $MNT"
	if ! is_btrfs "$MNT"; then
		echo "Path $MNT is not btrfs, skipping"
		continue
	fi

	if ! is_raid56 "$MNT"; then
		echo "RAID level is not 5 or 6, parallel device scrubbing"
		run_task btrfs scrub start -Bd $ioprio $readonly "$MNT"
	else
		echo "RAID level is 5 or 6, sequential device scrubbing"
		for DEV in $(btrfs filesystem show   "$MNT" |  awk '/ path /{print $NF}')
		do
			run_task btrfs scrub start -Bd $ioprio $readonly "$DEV"
			until btrfs scrub status "$DEV" | grep finished
				do
					sleep 5
				done
		done
	fi
	if [ "$?" != "0" ]; then
		echo "Scrub cancelled at $MNT"
		exit 1
	fi
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
