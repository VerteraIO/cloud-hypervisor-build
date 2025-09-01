%global debug_package %{nil}
%global selinux_module cloud-hypervisor

%if 0%{?el_version}
%global dist .el%{el_version}
%endif

Name:           cloud-hypervisor-selinux
Version:        %{version}
Release:        1%{?dist}
Summary:        SELinux policy for Cloud Hypervisor

License:        Apache-2.0
URL:            https://github.com/cloud-hypervisor/cloud-hypervisor
Source1:        RELEASE_NOTES.md
Source2:        rpm_changelog.txt
BuildArch:      noarch

BuildRequires:  selinux-policy-devel
BuildRequires:  policycoreutils-python-utils

Requires(post): policycoreutils
Requires(post): libselinux-utils
Requires(postun): policycoreutils
Requires:       selinux-policy-targeted
Requires:       cloud-hypervisor = %{version}-%{release}

%description
Custom SELinux policy module to confine the cloud-hypervisor service.

%prep
%setup -c -T
# Copy selinux files from the build directory
cp -r %{_builddir}/selinux .

%build
# Build the SELinux module
make -C selinux \
     MODNAME=%{selinux_module} \
     PP=%{selinux_module}.pp

%install
# Install the compiled policy and source (optional) into the subpkg payload
install -D -m 0644 selinux/%{selinux_module}.pp %{buildroot}%{_datadir}/selinux/packages/%{selinux_module}.pp
install -D -m 0644 selinux/%{selinux_module}.te %{buildroot}%{_datadir}/selinux/packages/%{selinux_module}.te
install -D -m 0644 selinux/%{selinux_module}.fc %{buildroot}%{_datadir}/selinux/packages/%{selinux_module}.fc

# Install release notes
install -d %{buildroot}%{_docdir}/%{name}
install -m 644 %{SOURCE1} %{buildroot}%{_docdir}/%{name}/RELEASE_NOTES.md

%post
if selinuxenabled 2>/dev/null; then
  # Install/upgrade the module idempotently
  semodule -i %{_datadir}/selinux/packages/%{selinux_module}.pp || :
  # Apply file contexts from .fc
  /sbin/restorecon -R /usr/bin/cloud-hypervisor /var/lib/cloud-hypervisor /var/log/cloud-hypervisor /etc/cloud-hypervisor || :
fi

%posttrans
# In case the policy landed before the files, ensure contexts are right after transaction
if selinuxenabled 2>/dev/null; then
  /sbin/restorecon -R /usr/bin/cloud-hypervisor /var/lib/cloud-hypervisor /var/log/cloud-hypervisor /etc/cloud-hypervisor || :
fi

%postun
# On erase, remove the module only if no longer needed
if [ $1 -eq 0 ] && selinuxenabled 2>/dev/null; then
  semodule -r %{selinux_module} 2>/dev/null || :
fi

%files
%dir %{_datadir}/selinux/packages
%{_datadir}/selinux/packages/%{selinux_module}.pp
%{_datadir}/selinux/packages/%{selinux_module}.te
%{_datadir}/selinux/packages/%{selinux_module}.fc
%doc %{_docdir}/%{name}/RELEASE_NOTES.md

%changelog
%include %{SOURCE2}
