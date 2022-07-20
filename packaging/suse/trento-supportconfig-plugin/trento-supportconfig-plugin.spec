#
# spec file for package trento-supportconfig-plugin
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


Name:      trento-supportconfig-plugin
# Version will be processed via set_version source service
Version:   0
Release:   0
License:   Apache-2.0
Summary:   Supportconfig plugin for trento
Group:     System/Monitoring
URL:       https://github.com/trento-project/helm-charts
Source:    %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-build
BuildArch: noarch
Provides:  %{name} = %{version}-%{release}
Requires:  supportconfig-plugin-resource
Requires:  supportconfig-plugin-tag
Requires:  trento-server-installer

%description
Supportconfig plugin for trento.

The script allows the user to collect all relevant installation details for a support request.

%prep
%setup -q # unpack project sources

%build

%install
pwd;ls -la
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT/usr/lib/supportconfig/plugins
install -d $RPM_BUILD_ROOT/sbin
install -m 0544 packaging/suse/trento-supportconfig-plugin/trento $RPM_BUILD_ROOT/usr/lib/supportconfig/plugins

%files
%defattr(-,root,root)
/usr/lib/supportconfig
/usr/lib/supportconfig/plugins
/usr/lib/supportconfig/plugins/trento

%clean
rm -rf $RPM_BUILD_ROOT
