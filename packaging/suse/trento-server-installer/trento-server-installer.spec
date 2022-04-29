#
# spec file for package trento-server-installer
#
# Copyright (c) 2022 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative   .

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:      trento-server-installer
# Version will be processed via set_version source service
Version:   0
Release:   0
License:   Apache-2.0
Summary:   Quickstart installer for the trento-server helm chart
Group:     System/Monitoring
URL:       https://github.com/trento-project/helm-charts
Source:    %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-build
BuildArch: noarch
Provides:  %{name} = %{version}-%{release}
Conflicts: trento-premium-server-installer

%description
Quickstart installer for the trento-server helm chart.

The script enables the user to get the Trento environment quickly deployed, installing all the
dependencies on the fly.

%prep
%setup -q # unpack project sources

%build

%install

# Install the default configuration files
%if 0%{?suse_version} > 1500
install -D -m 0640 packaging/suse/config/installer.conf %{buildroot}%{_distconfdir}/trento/installer.conf
%else
install -D -m 0640 packaging/suse/config/installer.conf %{buildroot}%{_sysconfdir}/trento/installer.conf
%endif

# Install the installer script.
install -D -m 0755 scripts/install-server.sh "%{buildroot}%{_bindir}/install-trento-server"

%files
%defattr(-,root,root)
%{_bindir}/install-trento-server

%if 0%{?suse_version} > 1500
%dir %{_distconfdir}/trento
%{_distconfdir}/trento/installer.conf
%else
%dir %{_sysconfdir}/trento
%config %{_sysconfdir}/trento/installer.conf
%endif

%changelog
