# Quick Reference Guide

**Linux Base Setup v2.2.1**

## Installation

```bash
# One-line install
curl -sSL https://raw.githubusercontent.com/crxnit/Linux-Base-Setup-2026/main/install.sh | sudo bash

# Manual install
git clone https://github.com/crxnit/Linux-Base-Setup-2026.git
cd Linux-Base-Setup-2026
sudo ./harden.sh
```

## After Installation (if using install.sh)

```bash
# Run from anywhere using the harden command
sudo harden --dry-run    # Preview changes
sudo harden              # Run hardening
```

## Common Commands

```bash
# Preview changes
sudo ./harden.sh --dry-run

# Run with defaults
sudo ./harden.sh

# Custom configuration
cp config/custom.conf.template config/custom.conf
nano config/custom.conf
sudo ./harden.sh --config config/custom.conf

# Non-interactive mode
sudo ./harden.sh --non-interactive

# Skip components
sudo ./harden.sh --skip-updates --skip-firewall

# Verbose output
sudo ./harden.sh --verbose
```

## Quick Configuration

### Web Server
```bash
# config/custom.conf
ADMIN_USERNAME="webadmin"
SSH_PORT=2222
UFW_ALLOWED_PORTS="22/tcp,80/tcp,443/tcp"
INSTALL_CROWDSEC=true
ENABLE_UNATTENDED_UPGRADES=true
```

### Database Server
```bash
# config/custom.conf
ADMIN_USERNAME="dbadmin"
SSH_PORT=2222
UFW_ALLOWED_PORTS="22/tcp,3306/tcp,5432/tcp"
CONFIGURE_APPARMOR=true
INSTALL_AUDITD=true
```

### High Security
```bash
# config/custom.conf
SSH_PORT=2222
SSH_PASSWORD_AUTH="no"
DISABLE_USB_STORAGE=true
CONFIGURE_APPARMOR=true
CROWDSEC_ENROLL=true
CROWDSEC_ENROLL_KEY="your-key"
PASSWORD_MIN_LENGTH=16
```

## Essential Checks After Running

### 1. Test SSH Connection (CRITICAL!)
```bash
# From another terminal
ssh -p 2222 admin@your-server-ip
```

### 2. Verify Firewall
```bash
sudo ufw status verbose
```

### 3. Check Services
```bash
sudo systemctl status sshd
sudo systemctl status crowdsec
sudo systemctl status auditd
```

### 4. Review Logs
```bash
sudo tail -100 /var/log/hardening/hardening-*.log
```

## Troubleshooting

### Locked Out of SSH
```bash
# Via console/KVM
sudo ufw disable
sudo ufw allow 2222/tcp
sudo ufw enable
sudo systemctl restart sshd
```

### Restore SSH Config
```bash
sudo cp /var/backups/hardening-*/sshd_config /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### View CrowdSec Status
```bash
sudo cscli metrics
sudo cscli decisions list
sudo cscli alerts list
sudo cscli decisions delete --ip <IP>  # Unban IP
```

### Auditd Reports
```bash
sudo ausearch -k identity        # User changes
sudo ausearch -k sshd_config     # SSH changes
sudo ausearch -k privileged-sudo # Sudo usage
```

## Monitoring Commands

```bash
# SSH attempts
sudo journalctl -u sshd -n 50 --no-pager

# Failed login attempts
sudo grep "Failed password" /var/log/auth.log

# Firewall log
sudo tail -f /var/log/ufw.log

# Audit log
sudo tail -f /var/log/audit/audit.log

# Security scan
sudo lynis audit system
sudo rkhunter --check
```

## File Locations

```bash
# Configuration
/opt/linux-base-setup/config/custom.conf

# Logs
/var/log/hardening/

# Backups
/var/backups/hardening-*/

# Scripts
/opt/linux-base-setup/
/usr/local/bin/harden (symlink)
```

## Help and Documentation

```bash
# Show help
./harden.sh --help

# View README
less README.md

# Check logs
cat /var/log/hardening/hardening-latest.log

# Completion report
cat /var/backups/hardening-*/completion_report.txt
```

## Configuration Options

### Most Common Settings

```bash
# User
ADMIN_USERNAME="username"
CREATE_ADMIN_USER=true

# SSH
SSH_PORT=2222
SSH_PASSWORD_AUTH="no"
SSH_PUBKEY_AUTH="yes"

# Firewall
FIREWALL_TYPE="ufw"
UFW_ALLOWED_PORTS="22/tcp,80/tcp,443/tcp"

# Security
INSTALL_CROWDSEC=true
INSTALL_AUDITD=true
INSTALL_RKHUNTER=true

# Updates
ENABLE_UNATTENDED_UPGRADES=true
PERFORM_UPDATES=true

# Time
NTP_SERVICE="chrony"
TIMEZONE="America/New_York"
```

## Best Practices

1. ✅ Always run `--dry-run` first
2. ✅ Test SSH connection before closing original session
3. ✅ Keep backup of working configuration
4. ✅ Review logs after completion
5. ✅ Run security audit periodically
6. ✅ Update system regularly
7. ✅ Monitor CrowdSec and auditd logs
8. ✅ Document any custom changes

## Emergency Recovery

### Via Console Access

```bash
# 1. Disable firewall
sudo ufw disable

# 2. Restore SSH config
sudo cp /var/backups/hardening-*/sshd_config /etc/ssh/sshd_config
sudo systemctl restart sshd

# 3. Re-enable firewall with correct rules
sudo ufw allow 22/tcp
sudo ufw enable

# 4. Test and fix
ssh user@server
```

### Restore All Configs

```bash
# Find backup
BACKUP=$(ls -td /var/backups/hardening-* | head -1)

# Restore files
sudo cp $BACKUP/sshd_config /etc/ssh/sshd_config
sudo cp $BACKUP/99-hardening.conf /etc/sysctl.d/

# Restart services
sudo systemctl restart sshd
sudo systemctl restart crowdsec
sudo sysctl -p
```

## Security Checklist

After running the script, verify:

- [ ] Can SSH with key authentication
- [ ] Sudo works for admin user
- [ ] Firewall allows required ports
- [ ] CrowdSec is running
- [ ] Auditd is recording events
- [ ] System time is correct
- [ ] Unattended upgrades enabled
- [ ] Reviewed completion report
- [ ] Documented admin credentials
- [ ] Tested from external connection

## Support

- Documentation: `/opt/linux-base-setup/README.md`
- Issues: https://github.com/crxnit/Linux-Base-Setup-2026/issues
- Logs: `/var/log/hardening/`
- Backups: `/var/backups/hardening-*/`

## Version

Current: **v2.2.1**

See [CHANGELOG.md](CHANGELOG.md) for full version history.
