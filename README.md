# Linux Base Setup v2.0

![Version](https://img.shields.io/badge/version-2.1.3-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-orange.svg)
![Architecture](https://img.shields.io/badge/arch-AMD64%20%7C%20ARM64%20%7C%20ARM32-green.svg)

**Modular, production-ready server hardening script for Debian/Ubuntu systems.**

## 🖥️ Platform Support

### Distributions
- ✅ **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- ✅ **Debian**: 11 (Bullseye), 12 (Bookworm)

### Architectures
- ✅ **AMD64/x86_64**: Fully supported (primary platform)
- ✅ **ARM64/aarch64**: Fully supported (tested on Raspberry Pi 4, AWS Graviton)
- ⚠️ **ARM32/armv7l**: Limited support (basic features)

See [PLATFORM_COMPATIBILITY.md](PLATFORM_COMPATIBILITY.md) for detailed compatibility information.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/crxnit/Linux-Base-Setup-2026.git
cd Linux-Base-Setup-2026

# Preview changes (dry run)
sudo ./harden.sh --dry-run

# Run with default configuration
sudo ./harden.sh

# Run with custom configuration
cp config/custom.conf.template config/custom.conf
nano config/custom.conf
sudo ./harden.sh --config config/custom.conf
```

## ✨ What's New in v2.0

- **Modular Architecture**: Clean separation of concerns with dedicated modules
- **Configuration Files**: Manage settings without editing scripts
- **Dry-Run Mode**: Preview all changes before applying
- **Better Error Handling**: Comprehensive error checking and rollback capability
- **Enhanced Logging**: Detailed, color-coded logging with timestamps
- **Progress Indicators**: Visual feedback for long-running operations
- **Non-Interactive Mode**: Full automation support for provisioning
- **Modern Security**: Updated SSH ciphers, fail2ban, AppArmor, and more
- **Comprehensive Testing**: Pre-flight checks and validation

## 📋 Features

### Core Hardening
- ✅ **SSH Hardening**
  - Custom port configuration
  - Disable root login and password authentication
  - Modern key exchange algorithms and ciphers
  - Optional two-factor authentication (2FA)
  - Connection rate limiting

- ✅ **Firewall Configuration**
  - UFW or firewalld support
  - Automatic SSH port allowance
  - Customizable port rules
  - Rate limiting for services

- ✅ **Kernel Hardening (sysctl)**
  - IP spoofing protection
  - SYN flood protection
  - ICMP broadcast/redirect protection
  - Kernel information restriction
  - Memory randomization (ASLR)

- ✅ **User Management**
  - Automated admin user creation
  - SSH key deployment
  - Password policy enforcement
  - Umask configuration

### Security Tools
- 🛡️ **Fail2Ban**: Intrusion prevention with custom SSH rules
- 📊 **Auditd**: Comprehensive file integrity and system call auditing
- 🔍 **RKHunter**: Rootkit detection
- 🔐 **Lynis**: Security auditing (optional)
- 🗃️ **AIDE**: Advanced intrusion detection (optional)

### System Configuration
- ⏰ **Time Synchronization**: Chrony or systemd-timesyncd
- 🔄 **Unattended Upgrades**: Automatic security updates
- 🏷️ **Hostname Management**: Auto-generated or custom hostnames
- 🚫 **Protocol Filtering**: Disable uncommon network protocols
- 🔒 **AppArmor**: Mandatory access control (optional)

## 📁 Project Structure

```
linux-base-setup-v2/
├── harden.sh                    # Main orchestration script
├── config/
│   ├── default.conf             # Default configuration
│   └── custom.conf.template     # Template for customization
├── modules/
│   ├── utils.sh                 # Utility functions
│   ├── user.sh                  # User management
│   ├── ssh.sh                   # SSH hardening
│   ├── firewall.sh              # Firewall configuration
│   ├── hardening.sh             # Kernel hardening
│   ├── security_tools.sh        # Security tool installation
│   └── updates.sh               # System updates & NTP
├── logs/                        # Execution logs
└── README.md
```

## ⚙️ Configuration

### Using Configuration Files

1. **Create custom configuration:**
```bash
cp config/custom.conf.template config/custom.conf
nano config/custom.conf
```

2. **Modify settings:**
```bash
# Example custom.conf
ADMIN_USERNAME="johndoe"
SSH_PORT=2222
FIREWALL_TYPE="ufw"
UFW_ALLOWED_PORTS="22/tcp,80/tcp,443/tcp,3000/tcp"
TIMEZONE="America/New_York"
```

3. **Run with custom config:**
```bash
sudo ./harden.sh --config config/custom.conf
```

### Key Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `SSH_PORT` | 2222 | Custom SSH port |
| `SSH_PASSWORD_AUTH` | no | Allow password authentication |
| `FIREWALL_TYPE` | ufw | Firewall type (ufw/firewalld/none) |
| `INSTALL_FAIL2BAN` | true | Install and configure Fail2Ban |
| `INSTALL_AUDITD` | true | Install and configure Auditd |
| `ENABLE_UNATTENDED_UPGRADES` | true | Enable automatic security updates |
| `NTP_SERVICE` | chrony | NTP service (chrony/systemd-timesyncd) |

See `config/default.conf` for complete list of options.

## 🎯 Usage Examples

### Interactive Mode (Default)
```bash
sudo ./harden.sh
```
Script will prompt for:
- Admin username
- Passwords
- SSH key deployment
- Hostname
- Timezone
- Optional features

### Non-Interactive Mode (Automation)
```bash
# Configure in custom.conf
INTERACTIVE=false
ADMIN_USERNAME="admin"
HOSTNAME="web-server-01"
TIMEZONE="UTC"

# Run
sudo ./harden.sh --non-interactive
```

### Dry Run (Preview Changes)
```bash
sudo ./harden.sh --dry-run
```
Shows what would be changed without applying modifications.

### Skip Specific Components
```bash
# Skip updates and firewall
sudo ./harden.sh --skip-updates --skip-firewall

# Skip security tools
sudo ./harden.sh --skip-fail2ban --skip-auditd
```

### Custom Configuration
```bash
# Use specific config file
sudo ./harden.sh --config /path/to/myconfig.conf

# Combine with other options
sudo ./harden.sh --config config/custom.conf --dry-run
```

## 🔒 Security Levels

### Basic Hardening
```bash
# config/custom.conf
CONFIGURE_SSH=true
SSH_PORT=2222
CONFIGURE_FIREWALL=true
INSTALL_FAIL2BAN=true
CONFIGURE_SYSCTL=true
```

### Medium Security
```bash
# Add to basic configuration
INSTALL_AUDITD=true
INSTALL_RKHUNTER=true
CONFIGURE_PASSWORD_POLICY=true
PASSWORD_MIN_LENGTH=12
DISABLE_UNCOMMON_PROTOCOLS=true
```

### High Security
```bash
# Add to medium configuration
SSH_PASSWORD_AUTH="no"
CONFIGURE_APPARMOR=true
DISABLE_USB_STORAGE=true
PASSWORD_MIN_LENGTH=16
FAIL2BAN_BAN_TIME=7200
FAIL2BAN_MAX_RETRY=3
# Enable 2FA during interactive setup
```

## 🎨 Server Type Configurations

### Web Server
```bash
UFW_ALLOWED_PORTS="22/tcp,80/tcp,443/tcp"
FIREWALL_TYPE="ufw"
INSTALL_FAIL2BAN=true
ENABLE_UNATTENDED_UPGRADES=true
```

### Database Server
```bash
UFW_ALLOWED_PORTS="22/tcp,3306/tcp,5432/tcp"
FIREWALL_TYPE="ufw"
CONFIGURE_APPARMOR=true
INSTALL_AUDITD=true
```

### Development Server
```bash
UFW_ALLOWED_PORTS="22/tcp,80/tcp,443/tcp,3000/tcp,8000/tcp,8080/tcp"
INSTALL_DOCKER=true
CONFIGURE_SYSCTL=true
```

## ⚠️ Important Warnings

### Before Running

1. **Backup Access**: Ensure you have alternative access to the server
2. **Test Environment**: Test on a non-production server first
3. **Firewall Rules**: Verify required ports are in allowed list
4. **SSH Keys**: Have your SSH public key ready
5. **Documentation**: Review log files after completion

### During Execution

1. **DO NOT CLOSE** your current SSH session
2. **Test new SSH connection** from separate terminal before disconnecting
3. **Verify firewall** allows SSH on new port
4. **Confirm SSH key** authentication works

### Critical Steps

```bash
# After script completion, from ANOTHER terminal:
ssh -p <NEW_PORT> <ADMIN_USER>@<SERVER_IP>

# Verify you can:
1. Connect with SSH key
2. Escalate to sudo
3. Access required services

# Only then close original session
```

## 📊 Logging and Monitoring

### Log Files
```bash
# Main execution log
/var/log/hardening/hardening-YYYYMMDD_HHMMSS.log

# Backup directory
/var/backups/hardening-YYYYMMDD_HHMMSS/

# Completion report
/var/backups/hardening-YYYYMMDD_HHMMSS/completion_report.txt
```

### Monitoring Commands

```bash
# View fail2ban status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# View auditd logs
sudo ausearch -k identity
sudo ausearch -k sshd_config

# View firewall status
sudo ufw status verbose
# or
sudo firewall-cmd --list-all

# View SSH connections
sudo journalctl -u sshd -n 50

# Run security audit
sudo lynis audit system
```

## 🔧 Troubleshooting

### SSH Connection Issues

```bash
# Test SSH config
sudo sshd -t

# Check SSH service
sudo systemctl status sshd
sudo journalctl -u sshd -n 50

# Verify firewall
sudo ufw status
sudo ufw allow <PORT>/tcp
```

### Firewall Lockout

```bash
# If locked out, access via console/KVM and:
sudo ufw disable
sudo ufw allow <SSH_PORT>/tcp
sudo ufw enable
```

### Restore from Backup

```bash
# Find backup
ls -la /var/backups/hardening-*/

# Restore SSH config
sudo cp /var/backups/hardening-*/sshd_config /etc/ssh/sshd_config
sudo systemctl restart sshd
```

## 🚦 Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Not running as root |
| 4 | Unsupported distribution |
| 5 | Pre-flight check failed |

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details

## 🙏 Credits

- Original script: linux-base-setup v1.0
- Modernized and modularized: v2.0
- Security best practices from CIS Benchmarks and NIST guidelines

## 📞 Support

- **Issues**: https://github.com/crxnit/Linux-Base-Setup-2026/issues
- **Discussions**: https://github.com/crxnit/Linux-Base-Setup-2026/discussions
- **Documentation**: https://github.com/crxnit/Linux-Base-Setup-2026/wiki

## 🔖 Version History

### v2.0.0 (Current)
- Complete modular rewrite
- Configuration file support
- Dry-run mode
- Enhanced error handling
- Modern security standards
- Comprehensive logging

### v1.0.0 (Legacy)
- Initial release
- Basic hardening features
- Single-file script

---

**⚠️ Always test in a non-production environment first!**

**Remember**: Security is a process, not a product. Regular updates, monitoring, and audits are essential.
