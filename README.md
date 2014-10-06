Btrfs maintenance toolbox
=========================

This is a set of scripts supplements the btrfs filesystem and aims to automate
a few maintenance tasks. This means the scrub, balance, trim or
defragmentation.

Each of the tasks can be turned on/off and configured independently. The
default config values were selected to fit the default installation profile of
openSUSE 13.2.

* scrub - go through all medatada/data and verify the checksums

* balance - the balance command can do a lot of things, in general moves data around in big chunks, here we use it to reclaim back the space of the underused chunks so it can be allocated again according to current needs

The point is to prevent some corner cases where it's not possible to eg.
allocate new metadata chunks because the whole device space is reserved for all
the chunks, although the total space occupied is smaller and the allocation
should succeed.

* trim - run TRIM on the filesystem using the 'fstrim' utility, makes sense for SSD devices

* defrag - run defrag on configured directories. This is for convenience and not necessary

There's a separate defragmentation task that happens automatically and
defragments only the RPM database files in /var/lib/rpm. This is done via a
zypper plugin and the defrag pass triggers at the end of the installation.

This improves reading the RPM databases later, but the installation process
fragments the files very quickly so it's not likely to bring a significant
speedup here.

Cron takes care of periodic execution of the scripts, but they can be run any
time directly from /usr/share/btrfs/maintenance/, respecting the confured
values in /etc/sysconfig/btrfsmaintenance.

If the period is changed manually, the cron symlinks have to be refreshed, use
"systemctl restart btrfsmaintenance-refresh" (or the
"rcbtrfsmaintenance-refresh" shortcut). Changing the period via yast2 sysconfig
editor triggers the refresh automatically.
