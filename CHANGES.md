version 0.4.2 (2018-09-25)
- CVE-2018-14722: expand auto mountpoints in a safe way
- btrfs-defrag: fix missing function to detect btrfs filesystems (#52)
- btrfs-trim: more verbose fstrim output (#60)
- dist-install: print information about timer unit installation (#58)

version 0.4.1 (2018-03-15)
- defrag plugin: python2 and 3 compatibility
- defrag plugin: target extent size lowered to 32MiB (#43)
- shell compatibility fixes
- systemd unit type fixes

version 0.4 (2018-01-18)

- add support for systemd timers and use them by default; the alternative cron
  scripts are still present (#29, #36)
- add automatic monitoring (via systemd.path) of the config file, no manual
  updates by btrfsmaintenance-refresh.service needed (#38)
- fix RPM database path detection
- spec file cleanups
- documentation updates

version 0.3.1 (2017-04-07)

- dist-install: fix installation paths, install functions
- functions: fix syntax to be compatible with dash
- spec: install functions file

version 0.3 (2016-11-15)

- add syslog to logging targets
- add none target (/dev/null)
- autodetect btrfs filesystems for balance, scrub and trim
- detect mixed blockgroups and use correct balance filters
- fix uninstall rules
- fix capturing entire output to the log
- fix when cron files are symlinks
- add generic installation script
- doc updates: retention policy tuning

version 0.2 (2016-03-04)

- updated documentation
- support debian-like configuration paths
- no hardcoded paths to external utilities
- fixed logger name typos for 'journal' target
- defrag fixes (sysconfig, find arguments)

version 0.1.2 (2015-10-08)

- change default config for trim: off
- journal loggin should work (fixed a typo)

version 0.1.1 (2015-07-13)

- fix typo and make journal logging target work
- cron refresh: remove bashism
- cron refresh: remove debugging messages
- post installation must create the cron links (bsc#904518)
- add COPYING, README.md
- add config option to specify log target (stdout, or journal)
- fix sysconfig file Path: tags

version 0.1 (2014-09-24)

- initial
