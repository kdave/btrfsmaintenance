Btrfs maintenance toolbox
=========================

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

__Special case:__

There's a separate defragmentation task that happens automatically and
defragments only the RPM database files in */var/lib/rpm*. This is done via a
*zypper* plugin and the defrag pass triggers at the end of the installation.

This improves reading the RPM databases later, but the installation process
fragments the files very quickly so it's not likely to bring a significant
speedup here.


## Other ##

Cron takes care of periodic execution of the scripts, but they can be run any
time directly from `/usr/share/btrfs/maintenance/`, respecting the configured
values in `/etc/sysconfig/btrfsmaintenance`.

If the period is changed manually, the cron symlinks have to be refreshed, use
`systemctl restart btrfsmaintenance-refresh` (or the
`rcbtrfsmaintenance-refresh` shortcut). Changing the period via *yast2* sysconfig
editor triggers the refresh automatically.


## Quick start ##

The tasks' periods and other parameters should fit most usecases and do not
need to be touched. Review the mountpoints (variables ending with
`_MOUNTPOINTS`) whether you want to run the tasks there or not.

## Distro integration ##

Currently the support for widely used distros is present.  More distros can be
added. This section describes how the pieces are put together and should give
some overview.

### Installation ###

* `btrfs-*.sh` task scripts are expected at `/usr/share/btrfsmaintenance`
* `sysconfig.btrfsmaintenance` configuration template is put to:
 * `/etc/sysconfig/btrfsmaintenance` on SUSE and RedHat based systems or derivatives
 * `/etc/default/btrfsmaintenance` on Debian and derivatives
* `/usr/lib/zypp/plugins/commit/btrfs-defrag-plugin.py` post-update script for
  zypper (the package manager), applies to SUSE-based distros for now
* cron refresh scripts are installed (see bellow)

### cron jobs ###

The periodic execution of the tasks is done by the 'cron' service.  Symlinks to
th task scripts are located in the respective directories in
`/etc/cron.<PERIOD>`.

The script `btrfsmaintenance-refresh-cron.sh` will synchronize the symlinks
according to the configuration files. This can be called automatically by a GUI
configuration tool if it's capable of running post-change scripts or services.
In that case there's `btrfsmaintenance-refresh.service` systemd service.

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

## About ##

The goal of this project is to help administering btrfs filesystems. It is not
supposed to be distribution specific. Common scripts/configs are preferred but
per-distro exceptions will be added when necessary.

Please open issues for bugs or feature requests.

Pull requests will be accepted if the patches satisfy some basic quality
requirements:

* descriptive subject lines
* changelogs that explain why the change is made (unless it's obvious)
* one logical change per patch (really simple changes can be grouped)
* the `Signed-off-by` line is optional but desirable, see [Developer Certificate of Origin](http://developercertificate.org/)

License: [GPL 2](https://www.gnu.org/licenses/gpl-2.0.html)
