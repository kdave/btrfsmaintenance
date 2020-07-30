#!/bin/sh -e

# Switch unmodified defaults from versions up to 0.4 to new defaults from 0.5+
# Usage: $0 [target file]

file=
dryrun=false

if [ -f /etc/sysconfig/btrfsmaintenance ] ; then
	file=/etc/sysconfig/btrfsmaintenance
fi

if [ -f /etc/default/btrfsmaintenance ] ; then
	file=/etc/default/btrfsmaintenance
fi

if [ -f "$1" ]; then
	file="$1"
fi

if ! [ -f "$file" ]; then
	echo "ERROR: config file for btrfsmaintenance not found: $file"
	exit 1
fi

fixup()
{
	if $dryrun; then
		grep "^$1\$" "$file"
	else
		sed -i -e "s,$1,$2," "$file"
	fi
}

fixup	'## Default:     "1 5 10 20 30 40 50"'			\
	'## Default:     "5 10"'

fixup	'BTRFS_BALANCE_DUSAGE="1 5 10 20 30 40 50"'		\
	'BTRFS_BALANCE_DUSAGE="5 10"'

fixup	'## Default:     "1 5 10 20 30"'			\
	'## Default:     "5"'

fixup	'BTRFS_BALANCE_MUSAGE="1 5 10 20 30"'			\
	'BTRFS_BALANCE_MUSAGE="5"'
