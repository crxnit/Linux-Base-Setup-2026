# Platform Compatibility Guide

## Supported Distributions

### Ubuntu
- ✅ **Ubuntu 24.04 LTS (Noble Numbat)** - Fully supported
- ✅ **Ubuntu 22.04 LTS (Jammy Jellyfish)** - Fully supported
- ✅ **Ubuntu 20.04 LTS (Focal Fossa)** - Fully supported
- ⚠️ **Ubuntu 18.04 LTS** - May work but EOL (April 2023)
- ⚠️ **Non-LTS versions** - May work but not recommended

### Debian
- ✅ **Debian 12 (Bookworm)** - Fully supported
- ✅ **Debian 11 (Bullseye)** - Fully supported
- ⚠️ **Debian 10 (Buster)** - May work but EOL approaching
- ⚠️ **Debian Testing/Unstable** - May work but not recommended

## Supported Architectures

### AMD64/x86_64 ✅
- **Status**: Fully supported
- **Features**: All features available
- **Testing**: Extensively tested
- **Notes**: Primary development platform

### ARM64/aarch64 ✅
- **Status**: Fully supported
- **Features**: All features available
- **Testing**: Tested on Raspberry Pi 4, AWS Graviton
- **Notes**: 
  - Some kernel parameters may not be available
  - Performance optimized for ARM64

### ARM32/armv7l ⚠️
- **Status**: Limited support
- **Features**: Most features available
- **Testing**: Basic testing only
- **Notes**:
  - Some advanced kernel hardening options unavailable
  - 32-bit limitations on memory settings
  - Recommended for testing/development only

## Distribution-Specific Differences

### Package Management

#### Ubuntu
- Uses `ubuntu:` prefixed package names when different from Debian
- Automatic security updates via `unattended-upgrades`
- ESM (Extended Security Maintenance) support for LTS versions

#### Debian
- Uses `debian:` prefixed package names when different from Ubuntu
- Security updates from `debian-security` repository
- More conservative package versions

### Repository Configuration

#### Ubuntu Origins
```
${distro_id}:${distro_codename}
${distro_id}:${distro_codename}-security
${distro_id}:${distro_codename}-updates
${distro_id}ESMApps:${distro_codename}-apps-security (LTS only)
${distro_id}ESM:${distro_codename}-infra-security (LTS only)
```

#### Debian Origins
```
origin=Debian,codename=${distro_codename},label=Debian
origin=Debian,codename=${distro_codename},label=Debian-Security
origin=Debian,codename=${distro_codename}-security,label=Debian-Security
```

## Architecture-Specific Differences

### Kernel Parameters

#### AMD64/x86_64
All sysctl parameters supported including:
- `kernel.exec-shield`
- `kernel.kexec_load_disabled`
- Full memory protection features

#### ARM64
Most sysctl parameters supported:
- `kernel.kexec_load_disabled` supported
- Some x86-specific features unavailable
- Optimized network buffers

#### ARM32
Limited sysctl support:
- Basic networking parameters supported
- Some advanced kernel hardening unavailable
- Reduced memory buffer sizes

### SSH Host Keys

#### All Architectures
- **Ed25519**: Supported (recommended)
- **RSA 4096**: Supported (fallback)
- **ECDSA**: Supported but not recommended

The script automatically detects and generates appropriate keys for your architecture.

### Cryptographic Algorithms

#### Modern Systems (Ubuntu 22.04+, Debian 12+)
All configured algorithms supported:
- ChaCha20-Poly1305
- AES-GCM
- Curve25519

#### Older Systems (Ubuntu 20.04, Debian 11)
Most algorithms supported:
- ChaCha20-Poly1305: ✅
- AES-GCM: ✅
- Curve25519: ✅

## Platform-Specific Features

### AppArmor

#### Ubuntu
- **Status**: Enabled by default
- **Profiles**: Extensive set included
- **Support**: First-class

#### Debian
- **Status**: Available but not default
- **Profiles**: Basic set included
- **Support**: Optional (must be enabled)

### Unattended Upgrades

#### Ubuntu
- Pre-configured for security updates
- ESM updates for LTS versions
- Automatic kernel updates

#### Debian
- Must be manually configured
- Security updates only by default
- Conservative update policy

## Tested Platforms

### Cloud Providers

#### AWS
- ✅ EC2 AMD64 instances
- ✅ EC2 Graviton (ARM64) instances
- ✅ Ubuntu AMIs
- ✅ Debian AMIs

#### DigitalOcean
- ✅ Standard droplets (AMD64)
- ✅ Ubuntu images
- ✅ Debian images

#### Hetzner
- ✅ Cloud servers (AMD64)
- ✅ Dedicated servers (AMD64)
- ✅ ARM cloud servers

#### Oracle Cloud
- ✅ AMD64 instances
- ✅ ARM (Ampere) instances

### Physical Hardware

#### x86_64
- ✅ Intel processors (Core, Xeon)
- ✅ AMD processors (Ryzen, EPYC)

#### ARM64
- ✅ Raspberry Pi 4 (4GB+)
- ✅ Raspberry Pi 5
- ✅ NVIDIA Jetson
- ✅ Apple Silicon (via virtualization)

#### ARM32
- ⚠️ Raspberry Pi 3/3B+
- ⚠️ Older ARM devices

## Known Limitations

### Ubuntu-Specific

1. **Snap packages**: Not managed by this script
2. **Cloud-init**: May conflict with hostname changes
3. **Ubuntu Pro**: ESM requires separate activation

### Debian-Specific

1. **Non-free firmware**: May need to enable non-free repos
2. **Backports**: Not automatically enabled
3. **Testing/Unstable**: May have dependency issues

### Architecture-Specific

#### ARM32
1. Limited to 4GB RAM addressing
2. Some kernel modules unavailable
3. Older OpenSSL versions on some systems
4. Performance limitations

#### ARM64
1. Some proprietary software unavailable
2. Docker on ARM64 has image availability issues
3. Some kernel modules differ from x86_64

## Compatibility Checking

The script automatically:

1. **Detects distribution** (Ubuntu vs Debian)
2. **Checks version** (warns if unsupported)
3. **Identifies architecture** (AMD64, ARM64, ARM32)
4. **Validates kernel** (checks for required features)
5. **Tests package availability** (before installation)

### Pre-flight Checks

```bash
# Manual compatibility check
./harden.sh --dry-run

# Check distribution
lsb_release -a

# Check architecture  
uname -m

# Check kernel version
uname -r
```

## Recommendations by Use Case

### Web Server (AMD64)
- **Platform**: Ubuntu 22.04 LTS or Debian 12
- **Architecture**: AMD64
- **Features**: All enabled

### IoT/Edge (ARM64)
- **Platform**: Ubuntu 22.04 LTS (ARM64)
- **Architecture**: ARM64
- **Features**: All enabled, optimized buffers

### Development (ARM)
- **Platform**: Raspberry Pi OS (based on Debian)
- **Architecture**: ARM64 or ARM32
- **Features**: Basic hardening recommended

### Container Host
- **Platform**: Ubuntu 22.04 LTS
- **Architecture**: AMD64 or ARM64
- **Features**: All enabled, Docker support

## Migration Notes

### Ubuntu 20.04 → 22.04
- No script changes required
- All features compatible
- Recommended upgrade path

### Debian 11 → 12
- No script changes required
- All features compatible
- Recommended upgrade path

### ARM32 → ARM64
- Full feature support gained
- No configuration changes needed
- Performance improvement

## Troubleshooting

### Distribution Detection Issues

```bash
# Force distribution
export FORCE_DISTRO="ubuntu"
# or
export FORCE_DISTRO="debian"
```

### Architecture Issues

```bash
# Check architecture
uname -m

# Verify 64-bit
getconf LONG_BIT
```

### Package Not Found

```bash
# Update package lists
sudo apt update

# Search for package
apt-cache search <package-name>
```

## Future Support

### Planned
- Ubuntu 26.04 LTS (when released)
- Debian 13 (Trixie)
- RISC-V architecture (experimental)

### Under Consideration
- Alpine Linux
- Rocky Linux / AlmaLinux
- FreeBSD (limited)

## Support Matrix

| Feature | Ubuntu 22.04 AMD64 | Ubuntu 22.04 ARM64 | Debian 12 AMD64 | Debian 12 ARM64 | ARM32 |
|---------|-------------------|-------------------|-----------------|-----------------|--------|
| SSH Hardening | ✅ | ✅ | ✅ | ✅ | ✅ |
| Firewall (UFW) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fail2Ban | ✅ | ✅ | ✅ | ✅ | ✅ |
| Auditd | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| Kernel Hardening | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| AppArmor | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| Unattended Upgrades | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2FA (Google Auth) | ✅ | ✅ | ✅ | ✅ | ✅ |

Legend:
- ✅ Fully supported
- ⚠️ Partial support / May require adjustments
- ❌ Not supported

---

**Last Updated**: December 2024  
**Script Version**: 2.0  
**Tested Platforms**: 15+ different configurations
