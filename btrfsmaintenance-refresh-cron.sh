#!/bin/sh
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
	EXPECTED="$1"
	SCRIPT="$2"
	echo "Refresh script $SCRIPT for $EXPECTED"

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
	PERIOD="$1"
	SERVICE="$2"
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
OnCalendar=$PERIOD
EOF
			systemctl enable "$SERVICE".timer &> /dev/null
			systemctl start "$SERVICE".timer &> /dev/null
			;;
	esac
}

#
# Add "ConditionPathIsReadWrite=" for each mount point.
#
refresh_conditions() {
    MOUNT_POINTS="$1"
    SERVICE="$2"
    if [ -z "$MOUNT_POINTS" ]; then
        rm -rf /etc/systemd/system/${SERVICE}.service.d
    else
        mkdir -p /etc/systemd/system/${SERVICE}.service.d/
        echo "[Unit]" > /etc/systemd/system/${SERVICE}.service.d/readwrite.conf
        OIFS="$IFS"
        IFS=:
        for mount_point in $MOUNT_POINTS; do
            echo "ConditionPathIsReadWrite=$mount_point" >> /etc/systemd/system/${SERVICE}.service.d/readwrite.conf
        done
        IFS="$OIFS"
    fi
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
                refresh_conditions "$BTRFS_BALANCE_MOUNTPOINTS" btrfs-balance
                refresh_conditions "$BTRFS_SCRUB_MOUNTPOINTS" btrfs-scrub
                refresh_conditions "$BTRFS_TRIM_MOUNTPOINTS" btrfs-trim
                refresh_conditions "$BTRFS_DEFRAG_PATHS" btrfs-defrag
                systemctl daemon-reload
		;;
	*)
		refresh_cron "$BTRFS_SCRUB_PERIOD" btrfs-scrub.sh
		refresh_cron "$BTRFS_DEFRAG_PERIOD" btrfs-defrag.sh
		refresh_cron "$BTRFS_BALANCE_PERIOD" btrfs-balance.sh
		refresh_cron "$BTRFS_TRIM_PERIOD" btrfs-trim.sh
		;;
esac

