#!/bin/sh
# usage: $0 [sysconfdir]
#
# Install configuration template, documentation and scripts. Target path is
# autodetected or can be overriden by the first argument.
#
# Common values of sysconfdir:
# - /etc/sysconfig
# - /etc/default

sysconfdir="$1"

if [ -z "$1" ]; then
	if [ -d /etc/sysconfig ]; then
		sysconfdir=/etc/sysconfig
	elif [ -d /etc/default ]; then
		sysconfdir=/etc/default
	else
		echo "Cannot detect sysconfig directory, please specify manually"
		exit 1
	fi
else
	sysconfdir="$1"
fi

install -oroot -groot -m644 sysconfig.btrfsmaintenance "$sysconfdir"/btrfsmaintenance
install -d -oroot -groot -m755 /usr/share/btrfsmaintenance
install -oroot -groot -m755 btrfs-*.sh /usr/share/btrfsmaintenance/
install -oroot -groot -m644 btrfsmaintenance-functions /usr/share/btrfsmaintenance/

echo "Installation path: $sysconfdir"
echo "Now edit cron periods and mount points in $sysconfdir/btrfsmaintenance then run ./btrfsmaintenance-refresh-cron.sh to update cron symlinks
"
