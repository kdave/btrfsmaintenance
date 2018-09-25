#
# spec file for package btrfsmaintenance
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


#Compat macro for new _fillupdir macro introduced in Nov 2017
%if ! %{defined _fillupdir}
  %define _fillupdir /var/adm/fillup-templates
%endif

Name:           btrfsmaintenance
Version:        0.4.2
Release:        0
Summary:        Scripts for btrfs periodic maintenance tasks
License:        GPL-2.0-only
Group:          System/Base
Url:            https://github.com/kdave/btrfsmaintenance
Source0:        %{name}-%{version}.tar.bz2
BuildRequires:  systemd
Requires:       btrfsprogs
Requires:       zypp-plugin-python
Requires:       libzypp(plugin:commit)
Supplements:    btrfsprogs
BuildArch:      noarch
%{?systemd_requires}

%description
Scripts for btrfs maintenance tasks like periodic scrub, balance, trim or defrag
on selected mountpoints or directories. Hints for periodic snapshot tuning (eg.
for snapper).

%prep
%setup -q

%build

%install
# scripts
install -m 755 -d %{buildroot}%{_datadir}/%{name}
install -m 755 btrfs-defrag.sh %{buildroot}%{_datadir}/%{name}
install -m 755 btrfs-balance.sh %{buildroot}%{_datadir}/%{name}
install -m 755 btrfs-scrub.sh %{buildroot}%{_datadir}/%{name}
install -m 755 btrfs-trim.sh %{buildroot}%{_datadir}/%{name}
install -m 755 btrfsmaintenance-refresh-cron.sh %{buildroot}%{_datadir}/%{name}
install -m 644 btrfsmaintenance-functions %{buildroot}%{_datadir}/%{name}

# systemd services and timers
install -m 755 -d %{buildroot}%{_unitdir}
install -m 644 -D btrfsmaintenance-refresh.service %{buildroot}%{_unitdir}
install -m 644 -D btrfsmaintenance-refresh.path %{buildroot}%{_unitdir}
install -m 644 -D btrfs-balance.service %{buildroot}%{_unitdir}
install -m 644 -D btrfs-defrag.service %{buildroot}%{_unitdir}
install -m 644 -D btrfs-scrub.service %{buildroot}%{_unitdir}
install -m 644 -D btrfs-trim.service %{buildroot}%{_unitdir}
install -m 644 -D btrfs-balance.timer %{buildroot}%{_unitdir}
install -m 644 -D btrfs-defrag.timer %{buildroot}%{_unitdir}
install -m 644 -D btrfs-scrub.timer %{buildroot}%{_unitdir}
install -m 644 -D btrfs-trim.timer %{buildroot}%{_unitdir}
install -m 755 -d %{buildroot}%{_sbindir}
ln -s %{_sbindir}/service %{buildroot}%{_sbindir}/rcbtrfsmaintenance-refresh

# zypp plugin
install -m 755 -d %{buildroot}%{_libexecdir}/zypp/plugins/commit
install -m 755 -D btrfs-defrag-plugin.py %{buildroot}%{_libexecdir}/zypp/plugins/commit

# config
install -m 755 -d %{buildroot}%{_fillupdir}
install -m 644 -D sysconfig.btrfsmaintenance %{buildroot}%{_fillupdir}

%pre
# if the new service files don't exist, we migrate from
# old version with old script, remove cron symlinks
[ ! -f %{_unitdir}/btrfs-balance.timer -a -f %{_datadir}/%{name}/btrfsmaintenance-refresh-cron.sh ]  && %{_datadir}/%{name}/btrfsmaintenance-refresh-cron.sh uninstall
%service_add_pre btrfsmaintenance-refresh.service btrfsmaintenance-refresh.path btrfs-balance.service btrfs-balance.timer btrfs-defrag.service btrfs-defrag.timer btrfs-scrub.service btrfs-scrub.timer btrfs-trim.service btrfs-trim.timer

%post
%service_add_post btrfsmaintenance-refresh.service btrfsmaintenance-refresh.path btrfs-balance.service btrfs-balance.timer btrfs-defrag.service btrfs-defrag.timer btrfs-scrub.service btrfs-scrub.timer btrfs-trim.service btrfs-trim.timer
%{fillup_only btrfsmaintenance}

%preun
%service_del_preun btrfsmaintenance-refresh.service btrfsmaintenance-refresh.path btrfs-balance.service btrfs-balance.timer btrfs-defrag.service btrfs-defrag.timer btrfs-scrub.service btrfs-scrub.timer btrfs-trim.service btrfs-trim.timer

%postun
%service_del_postun btrfsmaintenance-refresh.service btrfsmaintenance-refresh.path btrfs-balance.service btrfs-balance.timer btrfs-defrag.service btrfs-defrag.timer btrfs-scrub.service btrfs-scrub.timer btrfs-trim.service btrfs-trim.timer

%files
%license COPYING
%dir /usr/share/licenses
%doc README.md
%{_fillupdir}/sysconfig.btrfsmaintenance
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/*
%dir %{_libexecdir}/zypp/
%dir %{_libexecdir}/zypp/plugins
%dir %{_libexecdir}/zypp/plugins/commit
%{_libexecdir}/zypp/plugins/commit/btrfs-defrag-plugin.py
%{_unitdir}/btrfsmaintenance-refresh.path
%{_unitdir}/btrfsmaintenance-refresh.service
%{_unitdir}/btrfs-balance.service
%{_unitdir}/btrfs-defrag.service
%{_unitdir}/btrfs-scrub.service
%{_unitdir}/btrfs-trim.service
%{_unitdir}/btrfs-balance.timer
%{_unitdir}/btrfs-defrag.timer
%{_unitdir}/btrfs-scrub.timer
%{_unitdir}/btrfs-trim.timer
%{_sbindir}/rcbtrfsmaintenance-refresh

%changelog
