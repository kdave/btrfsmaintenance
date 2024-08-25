#!/bin/bash
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.

# Adjust symlinks of btrfs maintenance services according to the configs.
# Run with 'uninstall' to remove them again

umask 022
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

SCRIPTS=/usr/share/btrfsmaintenance

if [ -f /etc/sysconfig/btrfsmaintenance ]; then
    . /etc/sysconfig/btrfsmaintenance
fi

if [ -f /etc/default/btrfsmaintenance ]; then
    . /etc/default/btrfsmaintenance
fi

case "$1" in
	cron)
		BTRFS_TIMER_IMPLEMENTATION="cron"
		shift
		;;
	systemd-timer|timer)
		BTRFS_TIMER_IMPLEMENTATION="systemd-timer"
		shift
		;;
esac

refresh_cron() {
	local EXPECTED="$1"
	local SCRIPT="$2"
	local VALID=false
	local PERIOD
	local LINK
	local FILE

	echo "Refresh script $SCRIPT for $EXPECTED"

	for PERIOD in daily weekly monthly none uninstall; do
		if [ "$PERIOD" = "$EXPECTED" ]; then
			VALID=true
		fi
	done

	if ! $VALID; then
		echo "$EXPECTED is not a valid period for cron.  Not changing."
		return
	fi

	for PERIOD in daily weekly monthly; do
	        # NOTE: debian does not allow filenames with dots in /etc/cron.*
	        LINK="${SCRIPT%.*}"
		FILE="/etc/cron.$PERIOD/$LINK"
		if [ "$PERIOD" = "$EXPECTED" ]; then
			ln -sf "$SCRIPTS/$SCRIPT" "$FILE"
		else
			rm -f "$FILE"
		fi
	done
}

refresh_timer() {
	local PERIOD="$1"
	local SERVICE="$2"

	echo "Refresh timer $SERVICE for $PERIOD"

	case "$PERIOD" in
		uninstall|none)
			systemctl stop "$SERVICE".timer &> /dev/null
			systemctl disable "$SERVICE".timer &> /dev/null
			rm -rf /etc/systemd/system/"$SERVICE".timer.d
			;;
		*)
			mkdir -p /etc/systemd/system/"$SERVICE".timer.d/
			cat << EOF > /etc/systemd/system/"$SERVICE".timer.d/schedule.conf
[Timer]
OnCalendar=
OnCalendar=$PERIOD
EOF
			systemctl enable "$SERVICE".timer &> /dev/null
			systemctl start "$SERVICE".timer &> /dev/null
			OIFS="$IFS"
			IFS=:
      if [ "$BTRFS_IO_LIMIT" = "true" ] ; then
			  mkdir -p /etc/systemd/system/"$SERVICE".service.d
				echo '[Service]' > /etc/systemd/system/"$SERVICE".service.d/10-iolimits.conf
				for DEVICE in $BTRFS_IO_LIMIT_DEVICES ; do
				  echo "IOReadBandwidthMax=$DEVICE $BTRFS_IO_LIMIT_BW"
				  echo "IOWriteBandwidthMax=$DEVICE $BTRFS_IO_LIMIT_BW"
				  echo "IOReadIOPSMax=$DEVICE $BTRFS_IO_LIMIT_IOPS"
				  echo "IOWriteIOPSMax=$DEVICE $BTRFS_IO_LIMIT_IOPS"
				done >> /etc/systemd/system/"$SERVICE".service.d/10-iolimits.conf
				systemctl daemon-reload
			fi
			IFS="$OIFS"
			;;
	esac
}

if [ "$1" = 'uninstall' ]; then
	for SCRIPT in btrfs-scrub btrfs-defrag btrfs-balance btrfs-trim; do
		case "$BTRFS_TIMER_IMPLEMENTATION" in
			systemd-timer)
				refresh_timer uninstall "${SCRIPT}"
				;;
			*)
				refresh_cron uninstall "${SCRIPT}.sh"
				;;
		esac
	done
	exit 0
fi

case "$BTRFS_TIMER_IMPLEMENTATION" in
	systemd-timer)
                # Deinstall cron jobs, don't run it twice.
                for SCRIPT in btrfs-scrub btrfs-defrag btrfs-balance btrfs-trim; do
                  refresh_cron uninstall "${SCRIPT}.sh"
                done
		refresh_timer "$BTRFS_SCRUB_PERIOD" btrfs-scrub
		refresh_timer "$BTRFS_DEFRAG_PERIOD" btrfs-defrag
		refresh_timer "$BTRFS_BALANCE_PERIOD" btrfs-balance
		refresh_timer "$BTRFS_TRIM_PERIOD" btrfs-trim
		;;
	*)
		refresh_cron "$BTRFS_SCRUB_PERIOD" btrfs-scrub.sh
		refresh_cron "$BTRFS_DEFRAG_PERIOD" btrfs-defrag.sh
		refresh_cron "$BTRFS_BALANCE_PERIOD" btrfs-balance.sh
		refresh_cron "$BTRFS_TRIM_PERIOD" btrfs-trim.sh
		;;
esac

