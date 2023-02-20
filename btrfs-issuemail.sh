#!/bin/bash
#
# Copyright (c) 2022 Matthias Klumpp <matthias@tenstral.net>

umask 022
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

if [ -f /etc/sysconfig/btrfsmaintenance ] ; then
    . /etc/sysconfig/btrfsmaintenance
fi

if [ -f /etc/default/btrfsmaintenance ] ; then
    . /etc/default/btrfsmaintenance
fi

. $(dirname $(realpath "$0"))/btrfsmaintenance-functions

if [ -z "$BTRFS_MAILADDR" ]
then
      # no email set, nothing to do for us
      exit 0
fi

if ! command -v sendmail &> /dev/null
then
	echo "Failed to find sendmail, can not send emails about issues!" >/dev/stderr
	exit 1
fi

ISSUE_MAIL_SENT_FILE="/run/btrfs-issue-mail-sent"
if [ -f "$ISSUE_MAIL_SENT_FILE" ]; then
	if [[ $(find "$ISSUE_MAIL_SENT_FILE" -mtime +1 -print) ]]; then
		# delete issue sent file if it is older than a day, so
		# we will send all notifications again
		rm $ISSUE_MAIL_SENT_FILE
	fi
fi

BTRFS_STATS_MOUNTPOINTS=$(expand_auto_mountpoint "auto")
OIFS="$IFS"
IFS=:
for MM in $BTRFS_STATS_MOUNTPOINTS; do
	if ! is_btrfs "$MM"; then
		echo "Path $MM is not btrfs, skipping"
		continue
	fi
	DEVSTATS=$(btrfs device stats --check $MM 2>&1)
	if [ $? -ne 0 ]; then

		if [ -f "$ISSUE_MAIL_SENT_FILE" ]; then
			# check if we already sent an email
			if grep -Fxq "$MM" "$ISSUE_MAIL_SENT_FILE"; then
				# we've already mailed a report for issues on this
				# mountpoint today, don't send another one just yet
				continue
			fi
		fi

		sendmail -t <<EOF
To: $BTRFS_MAILADDR
Subject: Btrfs device issue on $MM @ $HOSTNAME

This is an automatically generated mail message from btrfs-issuemail
running on $HOSTNAME

An issue has been detected on the btrfs device mounted as $MM.
You will be getting this email daily until you clear the issue with 'btrfs device stats --reset $MM'
Faithfully yours, etc.

P.S. The 'btrfs device stats' output is:
$DEVSTATS

Filesystem usage:
$(btrfs fi df $MM 2>&1)
EOF
		# set flag that we already sent a mail about this today
		echo "$MM" >> $ISSUE_MAIL_SENT_FILE
        fi
done

exit 0
