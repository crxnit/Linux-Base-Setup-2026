# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2024-12-28

### Major Rewrite
Complete modular rewrite of the linux-base-setup script with modern best practices and enterprise-grade features.

### Added
- **Modular Architecture**
  - Separated functionality into dedicated modules (utils, user, ssh, firewall, hardening, security_tools, updates)
  - Clean separation of concerns for maintainability
  - Easy to extend and customize

- **Configuration Management**
  - External configuration files (default.conf, custom.conf)
  - Template-based customization
  - Environment-specific configurations
  - No need to edit scripts directly

- **Command-Line Interface**
  - Comprehensive argument parsing
  - `--dry-run` mode for safe preview
  - `--config` for custom configuration files
  - `--skip-*` flags for selective execution
  - `--interactive` / `--non-interactive` modes
  - `--verbose` mode for debugging

- **Enhanced Error Handling**
  - `set -euo pipefail` for strict error handling
  - Comprehensive validation functions
  - Rollback capability with backups
  - Detailed error messages and logging

- **Improved Logging**
  - Color-coded output (INFO, SUCCESS, WARNING, ERROR)
  - Timestamp on all log entries
  - Separate log files per execution
  - Comprehensive completion reports

- **New Features**
  - Progress indicators for long-running tasks
  - System information display
  - Pre-flight checks (root, distribution, disk space)
  - Configuration summary before execution
  - Two-factor authentication (2FA) support for SSH
  - Rate limiting for SSH connections
  - AppArmor configuration support
  - AIDE (Advanced Intrusion Detection) optional install
  - Lynis security auditing optional install

- **Modern SSH Hardening**
  - Updated cipher suites (ChaCha20-Poly1305, AES-GCM)
  - Modern key exchange algorithms (Curve25519)
  - MACs with ETM (Encrypt-Then-MAC)
  - Ed25519 host key generation
  - SSH banner configuration
  - Client alive settings to prevent timeouts

- **Enhanced Firewall Configuration**
  - Support for both UFW and firewalld
  - Automatic SSH port allowance (prevents lockouts)
  - Rate limiting support
  - Customizable port rules via configuration

- **Comprehensive Kernel Hardening**
  - IPv6 hardening rules
  - Filesystem protections (protected_hardlinks, protected_symlinks)
  - Core dump restrictions
  - Kernel module security
  - Shared memory security
  - Disable uncommon filesystems and protocols

- **Password Policy Enforcement**
  - Configurable password length and complexity
  - Password aging policies
  - Integration with libpam-pwquality
  - Apply to existing users option

- **Fail2Ban Enhancements**
  - Dedicated jail for SSH on custom port
  - SSH-DDOS protection jail
  - Configurable ban times and retry counts
  - Multiple protocol support ready

- **Auditd Comprehensive Rules**
  - Time change monitoring
  - User/group modification tracking
  - Sudo configuration monitoring
  - SSH configuration monitoring
  - Hostname and network changes
  - Kernel module loading/unloading
  - Privileged command execution tracking
  - File permission change monitoring
  - Unauthorized access attempt logging
  - File deletion tracking
  - Login/logout event monitoring

- **Unattended Upgrades**
  - Configurable auto-reboot settings
  - Email notifications
  - Automatic kernel package removal
  - Dependency cleanup
  - Configurable reboot time

- **Non-Interactive Mode**
  - Full automation support
  - Default values for all prompts
  - Suitable for provisioning systems
  - Ansible/Terraform compatible

- **Documentation**
  - Comprehensive README with examples
  - Configuration templates
  - Troubleshooting guide
  - Server type configurations (web, database, development)
  - Security level examples (basic, medium, high)

### Changed
- **Script Organization**
  - Moved from single monolithic script to modular architecture
  - Functions properly organized by responsibility
  - Reusable utility functions

- **User Creation**
  - Enhanced group membership checking
  - Better handling of existing users
  - Optional password generation for non-interactive mode

- **SSH Configuration**
  - Rewrote SSH configuration generation from scratch
  - Uses modern SSH hardening standards
  - Better validation and testing

- **Hostname Management**
  - Improved auto-generation algorithm
  - Better /etc/hosts handling
  - Proper verification

- **Sysctl Configuration**
  - Organized into dedicated configuration file
  - Boolean toggles for each setting
  - More comprehensive hardening rules

- **Service Management**
  - Consistent use of systemctl
  - Better service status checking
  - Enable and start in separate steps

### Fixed
- **Auditd Configuration**
  - Uncommented and fixed auditd section (was commented out in v1.0)
  - Added comprehensive audit rules
  - Proper service restart handling

- **Syntax Errors**
  - Fixed `echo -p` → `read -p` on line 232
  - Fixed conditional syntax throughout
  - Proper quote escaping

- **Variable Handling**
  - All variables properly quoted
  - Safer variable expansion
  - Better parameter substitution

- **Error Handling**
  - Functions return proper exit codes
  - Better error messages
  - Cleanup on error

- **Backup System**
  - Centralized backup directory
  - Timestamped backups
  - Comprehensive file backup before modification

### Security Improvements
- Modern cryptographic algorithms for SSH
- Kernel hardening best practices from CIS benchmarks
- Enhanced auditd rules for compliance
- Fail2Ban protection against brute force
- Unattended security updates
- AppArmor mandatory access control support
- Core dump and shared memory protections
- Protocol and USB device restrictions

### Developer Experience
- Modular code structure for easy maintenance
- Clear separation of concerns
- Comprehensive inline documentation
- Helper functions for common operations
- Consistent error handling patterns
- Easy to add new modules

### Operations
- Dry-run mode for safe testing
- Detailed logging for troubleshooting
- Backup creation before modifications
- Completion report generation
- Non-interactive mode for automation

## [1.0.0] - Previous Version

### Features
- Basic SSH hardening
- User creation
- Hostname configuration
- System updates
- Kernel hardening (sysctl)
- Time synchronization
- Auditd rules (commented out)
- Logging

### Issues
- Monolithic script structure
- Auditd section commented out
- Syntax errors in several places
- Limited error handling
- No configuration file support
- No dry-run capability
- Limited documentation

---

## Migration Guide from v1.0 to v2.0

If you're upgrading from v1.0:

1. **Review the new configuration system**:
   ```bash
   cp config/custom.conf.template config/custom.conf
   # Port your old settings to custom.conf
   ```

2. **Test with dry-run first**:
   ```bash
   sudo ./harden.sh --dry-run
   ```

3. **Key differences**:
   - SSH configuration is now templated (no more sed commands)
   - Auditd is now enabled by default
   - Firewall is configured automatically
   - More security tools available

4. **New features to try**:
   - Two-factor authentication
   - Rate limiting
   - AppArmor
   - Comprehensive auditd rules
