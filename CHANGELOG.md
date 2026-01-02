# Changelog

All notable changes to this project will be documented in this file.

## [2.2.0] - 2025-01-02

### Changed
- **CrowdSec Integration**: Replaced Fail2Ban with CrowdSec for modern intrusion prevention
  - CrowdSec provides collaborative, crowd-sourced threat intelligence
  - Automatic IP reputation checking against global blocklists
  - Real-time threat detection and response
  - Lower false positive rates through community validation

### Added
- **CrowdSec Features**:
  - Automatic repository setup and installation
  - SSH collection (`crowdsecurity/sshd`) for SSH attack detection
  - Linux collection (`crowdsecurity/linux`) for general Linux threats
  - Firewall bouncer support (iptables and nftables)
  - Optional CrowdSec Console enrollment for centralized management
  - Automatic systemd/auth.log detection for SSH log acquisition
  - Custom SSH port configuration support

- **New Configuration Options**:
  - `INSTALL_CROWDSEC` - Enable/disable CrowdSec installation
  - `CROWDSEC_INSTALL_BOUNCER` - Install firewall bouncer
  - `CROWDSEC_BOUNCER_TYPE` - Choose iptables or nftables
  - `CROWDSEC_COLLECTIONS` - Comma-separated list of collections to install
  - `CROWDSEC_ENROLL` - Enable Console enrollment
  - `CROWDSEC_ENROLL_KEY` - CrowdSec Console enrollment key

### Removed
- Fail2Ban installation and configuration
- `INSTALL_FAIL2BAN`, `FAIL2BAN_MAX_RETRY`, `FAIL2BAN_BAN_TIME`, `FAIL2BAN_FIND_TIME` options
- `--skip-fail2ban` command-line flag (replaced with `--skip-crowdsec`)

### Updated
- Documentation updated with CrowdSec commands and configuration
- README.md, QUICK_REFERENCE.md updated for v2.2.0
- Version banners and references updated

## [2.1.6] - 2024-12-30

### Changed
- **Error Handling**: Script now continues on component failures instead of exiting
  - Removed `set -e` to allow script to continue after errors
  - Added `run_step()` wrapper function to track failures
  - Failed components are logged and reported at the end
  - Summary section shows all components that encountered errors
  - Users can review log file for details on failures

### Fixed
- **Fail2Ban**: Fixed "Have not found any log file for sshd jail" error
  - Detects systemd systems without /var/log/auth.log
  - Explicitly sets `backend = systemd` for sshd jail when needed
  - Made service restart failures non-fatal

### Improved
- Script resilience - hardening continues even if individual components fail
- Better error reporting with summary at end of execution
- Each step clearly identified in output for easier troubleshooting

## [2.1.5] - 2024-12-30

### Fixed
- **Root Check**: Moved root check earlier, before any directory operations
  - Prevents confusing "mkdir: Permission denied" errors
  - User now sees clear "must be run as root" message immediately
- **Fail2Ban**: Fixed service failing to start on Debian 12 and Ubuntu 22.04+
  - Removed non-existent `sshd-ddos` filter that caused startup failure
  - Changed action from `action_mwl` (requires mail) to `action_` (basic ban)
  - Added `backend = auto` for systemd compatibility
  - Simplified sshd jail configuration
  - Added configuration test (`fail2ban-client -t`) before restart
  - Increased service startup wait time
- **RKHunter**: Made database update and baseline commands non-fatal
  - Network issues during `rkhunter --update` no longer crash script
  - Shows warning with manual command if update fails

## [2.1.4] - 2024-12-30

### Fixed
- **Root Check**: Moved root privilege check to run immediately, before banner display
- **Backup Warnings**: Fixed spurious "File does not exist" warnings for files created fresh
  - Only attempt backup if file already exists (jail.local, audit_rules, pwquality.conf, etc.)
  - Moved backup calls after dry-run checks where appropriate
- **Fail2Ban**: Fixed script exit when fail2ban-client status fails during startup
  - Made status check non-fatal with graceful warning
  - Changed start_service to restart_service for config reload
  - Increased startup wait time

### Changed
- **Dist-Upgrade**: Removed interactive prompt for dist-upgrade
  - Added `PERFORM_DIST_UPGRADE=false` config option (disabled by default)
  - Dist-upgrade only runs when explicitly enabled in config
- **README**: Added one-line install instructions to Quick Start section

### Improved
- Better error handling throughout backup and service operations
- More consistent dry-run behavior across all modules

## [2.1.3] - 2024-12-30

### Fixed
- **Dry-Run Mode**: Fixed script exiting when log/backup directories don't exist
  - Deferred log/backup directory creation until after argument parsing
  - `LOG_FILE` now set to `/dev/null` in dry-run mode (no files created)
  - Added dry-run handling to `install_essential_tools()` function
  - Added dry-run handling to `generate_completion_report()` function
  - Dry-run now works correctly on fresh systems without creating any files

- **Repository URLs**: Fixed incorrect URLs causing 404 errors
  - Fixed `REPO_URL` in `install.sh` to use correct repository name
  - Fixed git clone URL in README.md
  - Fixed all support/issues/wiki links in README.md
  - Fixed URLs in QUICK_REFERENCE.md

### Changed
- **install.sh**: Removed hardcoded version numbers from banners
- **Documentation**: Updated README.md and QUICK_REFERENCE.md with latest changes

## [2.1.2] - 2024-12-30

### Fixed
- **Symlink Path Resolution**: Fixed critical bug where config and modules could not be found when running via symlink
  - Script now properly resolves symlinks to find actual installation directory
  - Works correctly when installed to `/opt/linux-base-setup` and called via `/usr/local/bin/harden`
  - Searches multiple standard locations for config and modules directories
  - Provides clear error messages showing all attempted paths if files not found

### Changed
- **Path Resolution**: Enhanced directory detection with multiple fallback locations
  - Config locations: `$SCRIPT_DIR/config`, `/opt/linux-base-setup/config`, `/etc/linux-base-setup`
  - Module locations: `$SCRIPT_DIR/modules`, `/opt/linux-base-setup/modules`, `/usr/local/share/linux-base-setup/modules`
  - Automatic detection of correct paths regardless of installation method
  
- **install.sh**: Improved installation script
  - Updated to v2.1.2
  - Sets proper file permissions on all installed files
  - Better output showing installation details
  - Shows all relevant paths after installation

### Improved
- **Error Messages**: Path-not-found errors now show all locations that were searched
- **Help Output**: Final summary now shows actual config and module directories being used

## [2.1.1] - 2024-12-28

### Added
- **Essential Tools Check**: Automatic detection and installation of required tools
  - Checks for `sudo`, `curl`, and `vim` (or `nano` as fallback)
  - Installs missing tools automatically before main hardening process
  - Configures sudo group and permissions if sudo was just installed
  - Ensures all essential tools are available for script execution

### Fixed
- **Minimal Server Support**: Script now works on minimal/basic server installations
  - No longer assumes sudo is pre-installed
  - No longer assumes curl is available
  - No longer assumes a text editor is present
  - Resolves failures on fresh minimal Debian/Ubuntu installations

### Changed
- **Pre-flight Checks**: Enhanced to include essential tools installation
  - Tools are checked and installed before distribution detection
  - Clear messaging about which tools are being installed
  - Proper error handling if installation fails

## [2.1.0] - 2024-12-28

### Added - Platform Compatibility
- **Enhanced Distribution Detection**
  - Automatic detection of Ubuntu vs Debian
  - Version checking with warnings for unsupported versions
  - Distribution-specific package handling
  - Detailed platform information logging

- **Architecture Support**
  - Full AMD64/x86_64 support (primary platform)
  - Full ARM64/aarch64 support (Raspberry Pi, AWS Graviton, etc.)
  - Limited ARM32/armv7l support with appropriate warnings
  - Architecture-specific kernel parameter optimization
  - Architecture detection and validation

- **Distribution-Specific Configurations**
  - Ubuntu-specific unattended-upgrades origins (including ESM)
  - Debian-specific unattended-upgrades origins
  - Distribution-aware package installation
  - Platform-specific repository handling

- **Architecture-Specific Optimizations**
  - AMD64: Full kernel hardening (exec-shield, kexec_load_disabled)
  - ARM64: Optimized kernel parameters for ARM processors
  - ARM32: Safe fallback configuration with warnings
  - SSH host key generation adapted to architecture capabilities

- **Documentation**
  - New PLATFORM_COMPATIBILITY.md with comprehensive platform guide
  - Support matrix showing feature availability by platform
  - Known limitations documented
  - Migration notes for different platforms
  - Troubleshooting guide for platform-specific issues

### Changed
- **Distribution Detection**
  - Enhanced `check_distribution()` function with version validation
  - Added `get_distribution()`, `get_distribution_version()`, `get_distribution_codename()`
  - Added `is_ubuntu()`, `is_debian()` helper functions

- **Architecture Detection**
  - Added `get_architecture()` function
  - Added `is_arm()`, `is_amd64()`, `is_arm64()`, `is_arm32()` helper functions
  - Architecture information included in all generated config files

- **Package Installation**
  - Updated `install_package()` to support distribution-specific package names
  - Added automatic package list update if stale
  - Better error handling for missing packages

- **SSH Configuration**
  - Dynamic host key generation based on architecture
  - Architecture information added to SSH config comments
  - Fallback to RSA if Ed25519 unavailable (older systems)

- **Kernel Hardening**
  - Architecture-specific sysctl parameters
  - Conditional kernel hardening based on platform capabilities
  - Warning messages for unsupported parameters on ARM32
  - Architecture annotation in generated config files

- **Unattended Upgrades**
  - Separate configurations for Ubuntu vs Debian
  - Distribution-appropriate security update sources
  - Ubuntu ESM support for LTS versions
  - Debian security repository handling

### Improved
- Pre-flight checks now display distribution and architecture
- Better warning messages for untested platforms
- Interactive prompts for unsupported versions
- Graceful degradation on limited platforms (ARM32)

### Fixed
- Kernel parameters that don't exist on ARM failing silently
- Package names that differ between Ubuntu and Debian
- Unattended-upgrades configuration for Debian 12
- SSH host key generation on systems without Ed25519 support

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
