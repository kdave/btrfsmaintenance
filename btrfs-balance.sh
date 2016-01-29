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

check_helper()
{
	TMPCHK=/tmp/check_balance_${RANDOM}_`date +%F`.log
	touch $TMPCHK
	btrfs balance start -h > $TMPCHK 2>&1
	grep -q "only check if balance would make sense" $TMPCHK
	if [ "$?" != "0" ]; then
		echo "your balance doesn't not support --only-check"
		rm -f $TMPCHK
		exit 1
	fi
	rm -f $TMPCHK
}

{
OIFS="$IFS"
IFS=:
for MM in $BTRFS_BALANCE_MOUNTPOINTS; do
	CONT_DATA_BALANCE=1
	LOOP=10
	LAST_CHUNK_NUM=0

	IFS="$OIFS"
	if [ $(stat -f --format=%T "$MM") != "btrfs" ]; then
		echo "Path $MM is not btrfs, skipping"
		continue
	fi
	echo "Before balance of $MM"
	btrfs filesystem df "$MM"
	df -H "$MM"

	btrfs balance start -dusage=0 "$MM"

	check_helper

	# After remove empty data block groups, try only 10 times in case we
	# have too much balance work
	for i in `seq 1 $LOOP`; do
		# btrfs balance start '-c' option will print out a valid
		# 'dvrange' if it finds something
		STRING=`btrfs balance start -c $MM | tail -1`
		echo $STRING | grep -q "dvrange"
		if [ $? -eq 0 ]; then
			# for btrfs-debugfs, print $4, for btrfs-balance-start,
			# print $5
			VRANGE=`echo $STRING | awk -F ' ' '{print $5}'`
			echo "balance data block group: ($VRANGE)"
			STRING=`btrfs balance start $VRANGE $MM | tail -1`
			echo $STRING | grep -q "Done"
			if [ $? -eq 0 ]; then
				CHUNK_NUM=`echo $STRING | awk -F ' ' '{print $8}'`
				if [ $LAST_CHUNK_NUM -eq 0 ]; then
					LAST_CHUNK_NUM=${CHUNK_NUM}
				elif [ $LAST_CHUNK_NUM -eq $CHUNK_NUM ]; then
					echo "balance cannot reclaim space any more"
					CONT_DATA_BALANCE=0
					break
				fi
			fi
		else
			echo "balance cannot reclaim space any more"
			CONT_DATA_BALANCE=0
			break
		fi
	done
	# $CONT_DATA_BALANCE indicates if balance on data block group
	# would make sense
	if [ $CONT_DATA_BALANCE -eq 1 ]; then
		for BB in $BTRFS_BALANCE_DUSAGE; do
			# quick round to clean up the unused block groups
			btrfs balance start -v -dusage=$BB "$MM"
		done
	fi
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
	journal) systemd-cat -t "$LOGIDENTIFIER";;
	*) cat;;
esac

exit 0
