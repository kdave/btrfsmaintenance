Btrfs maintenance toolbox
=========================

Table of contents:
* [Quick start](#quick-start)
* [Distro integration](#distro-integration)
* [Tuning periodic snapshotting](#tuning-periodic-snapshotting)

This is a set of scripts supplementing the btrfs filesystem and aims to automate
a few maintenance tasks. This means the *scrub*, *balance*, *trim* or
*defragmentation*.

Each of the tasks can be turned on/off and configured independently. The
default config values were selected to fit the default installation profile
with btrfs on the root filesystem.

Overall tuning of the default values should give a good balance between effects
of the tasks and low impact of other work on the system. If this does not fit
your needs, please adjust the settings.

### scrub ###

__Description:__ Scrub operation reads all data and metadata from the devices
and verifies the checksums. It's not mandatory, but may point out problems with
faulty hardware early as it touches data that might not be in use and bitrot.

If thre's a redundancy of data/metadata, ie. the *DUP* or *RAID1/5/6* profiles, scrub
is able to repair the data autmatically if there's a good copy available.

__Impact when active:__ Intense read operations take place and may slow down or
block other filesystem activies, possibly only for short periods.

__Tuning:__

* the recommended period is once in a month but a weekly period is also acceptable
* you can turn off the automatic repair (`BTRFS_SCRUB_READ_ONLY`)
* the default IO priority is set to *idle* but scrub may take long to finish,
  you can change priority to *normal* (`BTRFS_SCRUB_PRIORITY`)

__Related commands:__

* you can check status of last scrub run (either manual or through the cron
  job) by `btrfs scrub status /path`
* you can cancel a running scrub anytime if you find it inconvenient (`btrfs
  scrub cancel /path`), the progress state is saved each 5 seconds and next
  time scrub will start from that point

### balance ###

__Description:__ The balance command can do a lot of things, in general moves
data around in big chunks. Here we use it to reclaim back the space of the
underused chunks so it can be allocated again according to current needs.

The point is to prevent some corner cases where it's not possible to eg.
allocate new metadata chunks because the whole device space is reserved for all
the chunks, although the total space occupied is smaller and the allocation
should succeed.

The balance operation needs enough workspace so it can shuffle data around. By
workspace we mean device space that has no filesystem chunks on it, not to be
confused by free space as reported eg. by `df`.

__Impact when active:__ Possibly big. There's a mix of read and write operations, is
seek-heavy on a rotational devices. This can interfere with other work in case
the same set of blocks is affected.

The balance command uses filters to do the work in smaller batches.

__Expected result:__ If possible all the underused chunks are removed, the
value of `total` in output of `btrfs fi df /path` should be lower than before.
Check the logs.

The balance command may fail with *no space* reason but this is considered a
minor fault as the internal filesystem layout may prevent fhe command to find
enough workspace. This might be a time for manual inspection of space.

__Tuning:__

* you can make the space reclaim more aggressive by adding higher percentage to
  `BTRFS_BALANCE_DUSAGE` or `BTRFS_BALANCE_MUSAGE`. Higher value means bigger
  impact on your system and becomes very noticeable.
* the metadata chunks usage pattern is different from data and it's not
  necessary to reclaim metadata block groups that are more than 50 full. The
  default maximum is 30 which should not degrade performance too much but may
  be suboptimal if the metadata usage varies wildly over time. The assumption
  is that underused metadata chunks will get used at some point so it's not
  absolutelly required to do the reclaim.
* the useful period highly depends on the overall data change pattern on the
  filesystem

### trim ###

__Description:__ The TRIM operation (aka. *discard*) can instruct the underlying device to
optimize blocks that are not used by the filesystem. This task is performed
on-demand by the *fstrim* utility.

This makes sense for SSD devices or other type of storage that can translate
the TRIM action to someting useful (eg. thin-provisioned storage).

__Impact when active:__ Should be low, but depends on the amount of blocks
being trimmed.

__Tuning:__

* the recommended period is weekly, but monthly is also fine
* the trim commands might not have an effect and are up to the device, eg. a
  block range too small or other constraints that may differ by device
  type/vendor/firmware
* the default configuration is *off* because of the the system fstrim.timer

### defrag ###

__Description:__ Run defragmentation on configured directories. This is for
convenience and not necessary as defragmentation needs are usually different
for various types of data.

Please note that the defragmentation process does not descend to other mount
points and nested subvolumes or snapshots. All nested paths would need to be
enumerated in the respective config variable. The command utilizes `find
-xdev`, you can use that to verify in advance which paths will the
defragmentation affect.

__Special case:__

There's a separate defragmentation task that happens automatically and
defragments only the RPM database files. This is done via a *zypper* plugin
and the defrag pass triggers at the end of the installation.

This improves reading the RPM databases later, but the installation process
fragments the files very quickly so it's not likely to bring a significant
speedup here.


## Periodic scheduling ##

There are now two ways how to schedule and run the periodic tasks: cron and
systemd timers. Only one can be active on a system and this should be decided
at the installation time.

### Cron ###

Cron takes care of periodic execution of the scripts, but they can be run any
time directly from `/usr/share/btrfs/maintenance/`, respecting the configured
values in `/etc/sysconfig/btrfsmaintenance`.

The changes to configuration file need to be refleced in the `/etc/cron`
directories where the scripts are linked for the given period.

If the period is changed, the cron symlinks have to be refreshed:

* manually -- use `systemctl restart btrfsmaintenance-refresh` (or the `rcbtrfsmaintenance-refresh` shortcut)
* in *yast2* -- sysconfig editor triggers the refresh automatically
* using a file watcher -- if you install `btrfsmaintenance-refresh.path`, this will utilize the file monitor to detect changes and will run the refresh

### Systemd timers ###

There's a set of timer units that run the respective task script. The periods
are configured in the `/etc/sysconfig/btrfsmaintenance` file as well. The
timers have to be installed using a similar way as cron.  Please note that the
'*.timer' and respective '*.service' files have to be installed so the timers
work properly.


## Quick start ##

The tasks' periods and other parameters should fit most usecases and do not
need to be touched. Review the mountpoints (variables ending with
`_MOUNTPOINTS`) whether you want to run the tasks there or not.

## Distro integration ##

Currently the support for widely used distros is present.  More distros can be
added. This section describes how the pieces are put together and should give
some overview.

### Installation ###

For debian based systems, run `dist-install.sh` as root.

For non-debian based systems, check for distro provided package or
do manual installation of files as described below.

* `btrfs-*.sh` task scripts are expected at `/usr/share/btrfsmaintenance`
* `sysconfig.btrfsmaintenance` configuration template is put to:
 * `/etc/sysconfig/btrfsmaintenance` on SUSE and RedHat based systems or derivatives
 * `/etc/default/btrfsmaintenance` on Debian and derivatives
* `/usr/lib/zypp/plugins/commit/btrfs-defrag-plugin.py` post-update script for
  zypper (the package manager), applies to SUSE-based distros for now
* cron refresh scripts are installed (see bellow)

### cron jobs ###

The periodic execution of the tasks is done by the 'cron' service.  Symlinks to
the task scripts are located in the respective directories in
`/etc/cron.<PERIOD>`.

The script `btrfsmaintenance-refresh-cron.sh` will synchronize the symlinks
according to the configuration files. This can be called automatically by a GUI
configuration tool if it's capable of running post-change scripts or services.
In that case there's `btrfsmaintenance-refresh.service` systemd service.

This service can also be automatically started upon any modification of the
configuration file in `/etc/sysconfig/btrfsmaintenance` by installing the
`btrfsmaintenance-refresh.path` systemd watcher.

### Post-update defragmentation ###

The package database files tend to be updated in a random way and get
fragmented, which particularly hurts on btrfs. For rpm-based distros this means files
in `/var/lib/rpm`. The script or plugin simpy runs a defragmentation on the affected files.
See `btrfs-defrag-plugin.py` for more details.

At the moment the 'zypper' package manager plugin exists. As the package
managers differ significantly, there's no single plugin/script to do that.

### Settings ###

The settings are copied to the expected system location from the template
(`sysconfig.btrfsmaintenance`). This is a shell script and can be sourced to obtain
values of the variables.

The template contains descriptions of the variables, default and possible
values and can be deployed without changes (expecting the root filesystem to be
btrfs).

## Tuning periodic snapshotting ##

There are various tools and handwritten scripts to manage periodic snapshots
and cleaning. The common problem is tuning the retention policy constrained by
the filesystem size and not running out of space.

This section will describe factors that affect that, using [snapper](https://snapper.io)
as an example, but adapting to other tools should be straightforward.

### Intro ###

Snapper is a tool to manage snapshots of btrfs subvolumes. It can create
snapshots of given subvolume manually, periodically or in a pre/post way for
a given command. It can be configured to retain existing snapshots according
to time-based settings. As the retention policy can be very different for
various usecases, we need to be able to find matching settings.

The settings should satisfy user's expectation about storing previous copies of
the subvolume but not taking too much space. In an extreme, consuming the whole
filesystem space and preventing some operations to finish.

In order to avoid such situations, the snapper settings should be tuned according
to the expected usecase and filesystem size.

### Sample problem ###

Default settings of snapper on default root partition size can easily lead to
no-space conditions (all TIMELINE values set to 10). Frequent system updates
make it happen earlier, but this also affects long-term use.

### Factors affecting space consumption ###

1. frequency of snapshotting
2. amount of data changes between snapshots (delta)
4. snapshot retention settings
3. size of the filesystem

Each will be explained below.

The way how the files are changed affects the space consumption. When a new
data overwrite existing, the new data will be pinned by the following snapshot,
while the original data will belong to previous snapshot.  This means that the
allocated file blocks are freed after the last snapshot pointing to them is
gone.

### Tuning

The administrator/user is suppsed to know the approximate use of the partition
with snapshots enabled.

The decision criteria for tuning is space consumption and we're optimizing to
maximize retention without running out of space.

All the factors are intertwined and we cannot give definite answers but rather
describe the tendencies.

#### Snapshotting frequency

* **automatic**: if turned on with the `TIMELINE` config option, the periodic
  snapshots are taken hourly. The daily/weekly/monthly/yearly periods will keep
  the first hourly snapshot in the given period.

* **at package update**: package manager with snapper support will create
  pre/post snapshots before/after an update happens.

* **manual**: the user can create a snapshot manually with `snapper create`,
  with a given snapshot type (ie. single, pre, post).

#### Amount of data change

This is a parameter hard to predict and calculate. We work with rough
estimates, eg. megabytes, gigabytes etc.

#### Retention settings

The user is supposed to know possible needs of recovery or examination of
previous file copies stored in snapshots.

It's not recommended to keep too old snapshots, eg. monthly or even yearly if
there's no apparent need for that. The yearly snapshots should not substitute
backups, as they reside on the same partition and cannot be used for recovery.

#### Filesystem size

Bigger filesystem allows for longer retention, higher frequency updates and
amount of data changes.

As an example of a system root partition, the recommended size is 30 GiB, but
50 GiB is selected by the installer if the snapshots are turned on.

For non-system partition it is recommended to watch remaining free space.
Although getting an accurate value on btrfs is tricky, due to shared extents
and snapshots, the output of `df` gives a rough idea. Low space, like under a
few gigabytes is more likely to lead to no-space conditions, so it's a good
time to delete old snapshots or review the snapper settings.


### Typical usecases

#### A rolling distro

* frequency of updates: high, multiple times per week
* amount of data changed between updates: high

Suggested values:

    TIMELINE_LIMIT_HOURLY="12"
    TIMELINE_LIMIT_DAILY="5"
    TIMELINE_LIMIT_WEEKLY="2"
    TIMELINE_LIMIT_MONTHLY="1"
    TIMELINE_LIMIT_YEARLY="0"

The size of root partition should be at least 30GiB, but more is better.

#### Regular/enterprise distro

* frequency of updates: low, a few times per month
* amount of data changed between updates: low to moderate

Most data changes come probably from the package updates, in the range of
hundreds of megabytes per update.

Suggested values:

    TIMELINE_LIMIT_HOURLY="12"
    TIMELINE_LIMIT_DAILY="7"
    TIMELINE_LIMIT_WEEKLY="4"
    TIMELINE_LIMIT_MONTHLY="6"
    TIMELINE_LIMIT_YEARLY="1"

#### Big file storage

* frequency of updates: moderate to high
* amount of data changed between updates: no changes in files, new files added, old deleted

Suggested values:

    TIMELINE_LIMIT_HOURLY="12"
    TIMELINE_LIMIT_DAILY="7"
    TIMELINE_LIMIT_WEEKLY="4"
    TIMELINE_LIMIT_MONTHLY="6"
    TIMELINE_LIMIT_YEARLY="0"

Note, that deleting a big file that has been snapshotted will not free the space
until all relevant snapshots are deleted.

#### Mixed

* frequency of updates: unpredictable
* amount of data changed between updates: unpredictable

Examples:

* home directory with small files (in range of kilobytes to megabytes), large files (hundreds of megabytes to gigabytes).
* git trees, bare and checked out repositories

Not possible to suggest config numbers as it really depends on user
expectations. Keeping a few hourly snapshots should not consume too much space
and provides a copy of files, eg. to restore after accidental deletion.

Starting point:

    TIMELINE_LIMIT_HOURLY="12"
    TIMELINE_LIMIT_DAILY="7"
    TIMELINE_LIMIT_WEEKLY="1"
    TIMELINE_LIMIT_MONTHLY="0"
    TIMELINE_LIMIT_YEARLY="0"

### Summary

|  Type       |  Hourly  |  Daily  |  Weekly  |  Monthly  |  Yearly  |
--- | ---: | ---: | ---: | ---: | ---: |
|  Rolling    |  12      |  5      |  2       |  1        |  0       |
|  Regular    |  12      |  7      |  4       |  6        |  1       |
|  Big files  |  12      |  7      |  4       |  6        |  0       |
|  Mixed      |  12      |  7      |  1       |  0        |  0       |

## About ##

The goal of this project is to help administering btrfs filesystems. It is not
supposed to be distribution specific. Common scripts/configs are preferred but
per-distro exceptions will be added when necessary.

License: [GPL 2](https://www.gnu.org/licenses/gpl-2.0.html)

[Contributing guide](CONTRIBUTING.md).
