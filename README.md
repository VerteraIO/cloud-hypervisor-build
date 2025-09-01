# Cloud Hypervisor RPM Build System

This repository provides automated GitHub workflows and RPM packaging for [Cloud Hypervisor](https://github.com/cloud-hypervisor/cloud-hypervisor) targeting Enterprise Linux 9 and 10 (Rocky Linux).

## Overview

Cloud Hypervisor is a Virtual Machine Monitor (VMM) for modern cloud workloads, written in Rust with a focus on security and performance. This build system creates RPM packages for easy deployment on RHEL-compatible systems.

## Features

- **Multi-platform builds**: Supports EL9 and EL10 using Rocky Linux containers
- **Automated CI/CD**: GitHub Actions workflow for continuous integration
- **RPM packaging**: Creates both main package and SELinux policy subpackage
- **Security-focused**: Includes proper SELinux policies and systemd integration
- **Static linking**: Builds statically linked binaries for better portability

## Package Structure

### cloud-hypervisor
Main package containing:
- `/usr/bin/cloud-hypervisor` - The main VMM binary
- `/usr/lib/systemd/system/cloud-hypervisor.service` - Systemd service
- `/etc/cloud-hypervisor/config.toml` - Default configuration
- `/var/lib/cloud-hypervisor/` - Runtime data directory
- `/var/log/cloud-hypervisor/` - Log directory

### cloud-hypervisor-selinux
SELinux policy subpackage providing:
- Custom SELinux policy module for Cloud Hypervisor
- Proper file contexts and domain transitions
- Network and virtualization permissions

## Usage

### Building Locally

1. **Prerequisites** (Rocky Linux 9/10):
```bash
dnf install -y epel-release
dnf config-manager --set-enabled crb
dnf install -y git gcc gcc-c++ make cmake rpm-build rpmdevtools \
               curl m4 bison flex libuuid-devel musl-gcc openssl-devel \
               pkg-config systemd-devel libcap-devel selinux-policy-devel \
               checkpolicy policycoreutils-devel
```

2. **Install Rust**:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-unknown-linux-musl
```

3. **Build RPMs**:
```bash
git clone https://github.com/cloud-hypervisor/cloud-hypervisor.git
cd cloud-hypervisor
export CH_VERSION=$(git describe --tags --always)
export CH_COMMIT=$(git rev-parse HEAD)

rpmdev-setuptree
cp ../packaging/*.spec ~/rpmbuild/SPECS/

# Build source tarball
tar --exclude='.git' --exclude='target' -czf ~/rpmbuild/SOURCES/cloud-hypervisor-${CH_VERSION}.tar.gz ../cloud-hypervisor/

# Build packages
rpmbuild -ba ~/rpmbuild/SPECS/cloud-hypervisor.spec --define "version ${CH_VERSION}" --define "commit ${CH_COMMIT}"
rpmbuild -ba ~/rpmbuild/SPECS/cloud-hypervisor-selinux.spec --define "version ${CH_VERSION}"
```

### GitHub Actions

The workflow automatically triggers on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual workflow dispatch
- Git tags (creates releases)

Artifacts are uploaded for each EL version and automatically attached to releases when tags are pushed.

### Installation

1. **Install main package**:
```bash
sudo dnf install cloud-hypervisor-*.rpm
```

2. **Install SELinux policy** (recommended):
```bash
sudo dnf install cloud-hypervisor-selinux-*.rpm
```

3. **Enable and start service**:
```bash
sudo systemctl enable --now cloud-hypervisor
```

### Configuration

Edit `/etc/cloud-hypervisor/config.toml` to customize VM settings:

```toml
[vm]
cpus = "boot=2,max=8"
memory = "size=1G,hotplug_method=acpi,hotplug_size=16G"
kernel = "/path/to/vmlinux"
cmdline = "console=ttyS0 reboot=k panic=1 pci=off"

[disk]
path = "/var/lib/cloud-hypervisor/disk.img"
readonly = false

[net]
tap = "tap0"
mac = "12:34:56:78:90:ab"
```

## Security

### SELinux Integration
The SELinux policy provides:
- Confined domain for cloud-hypervisor process
- Network administration capabilities for TAP interfaces
- KVM device access permissions
- Proper file contexts for logs and data

### Systemd Security
The service runs with:
- Dedicated `cloud-hypervisor` user/group
- Restricted capabilities (CAP_NET_ADMIN only)
- Private temporary directories
- Protected system directories

## Development

### File Structure
```
.
├── .github/workflows/
│   └── build-rpm.yml          # GitHub Actions workflow
├── packaging/
│   ├── cloud-hypervisor.spec  # Main RPM spec
│   └── cloud-hypervisor-selinux.spec # SELinux RPM spec
└── README.md
```

### Customization

To modify the build:
1. Edit spec files in `packaging/`
2. Update workflow in `.github/workflows/build-rpm.yml`
3. Test locally before committing

### Contributing

1. Fork this repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request

## Troubleshooting

### Common Issues

**Permission denied when starting VMs:**
- Ensure SELinux policy is installed: `sudo dnf install cloud-hypervisor-selinux`
- Check SELinux status: `sestatus`
- Review audit logs: `sudo ausearch -m avc -ts recent`

**Network setup fails:**
- Verify CAP_NET_ADMIN capability: `getcap /usr/bin/cloud-hypervisor`
- Check user permissions for TAP devices
- Ensure bridge-utils is installed if using bridged networking

**Build failures:**
- Verify all build dependencies are installed
- Check Rust toolchain: `rustc --version`
- Ensure musl target is available: `rustup target list --installed`

### Logs

- Service logs: `journalctl -u cloud-hypervisor`
- Application logs: `/var/log/cloud-hypervisor/`
- SELinux denials: `sudo ausearch -m avc`

## License

This build system is provided under the same license terms as Cloud Hypervisor (Apache-2.0 OR BSD-3-Clause).

## Links

- [Cloud Hypervisor Project](https://github.com/cloud-hypervisor/cloud-hypervisor)
- [Cloud Hypervisor Documentation](https://github.com/cloud-hypervisor/cloud-hypervisor/tree/main/docs)
- [Rocky Linux](https://rockylinux.org/)
