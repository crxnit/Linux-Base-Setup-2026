# Enhanced Cloud-Init Template

This enhanced cloud-init template includes security, portability, and efficiency improvements over the original template.

## Key Improvements

### Security Enhancements
- **Configurable sudo**: Choose between passwordless sudo or password-required sudo
- **SSH forwarding controls**: Configurable agent and TCP forwarding restrictions
- **IPv6 configurability**: Enable/disable IPv6 and router advertisement acceptance
- **AppArmor integration**: Automatic AppArmor setup for application sandboxing
- **Enhanced SSH host keys**: Generates RSA, Ed25519, and ECDSA host keys
- **Improved security limits**: File descriptor and process limits

### Portability Improvements
- **Distribution detection**: Automatically detects Linux distribution (Ubuntu, Debian, etc.)
- **Architecture awareness**: Detects x86_64, ARM64, etc. for future extensibility
- **Service manager abstraction**: Works with systemd and SysV init systems
- **Error handling**: Better error detection and reporting

### Efficiency Improvements
- **Optimized package list**: Core packages only, development tools optional
- **Consolidated commands**: Reduced number of runcmd operations
- **Better error handling**: Commands fail gracefully with warnings
- **Enhanced logging**: Detailed completion logs with system information

## Usage

### Manual Template Usage
```bash
cp cloud-init-enhanced.yaml.template my-cloud-init.yaml
# Edit and replace {{PLACEHOLDER}} values
```

### Configuration Options

#### Core Settings
- `{{TIMEZONE}}`: System timezone (e.g., America/New_York)
- `{{ADMIN_USERNAME}}`: Admin username
- `{{SSH_PUBLIC_KEY}}`: Your SSH public key
- `{{SSH_PORT}}`: SSH port (default: 22, recommended: 2222)

#### Security Settings
- `{{ADMIN_SUDO_CONFIG}}`: `"ALL=(ALL) NOPASSWD:ALL"` (passwordless) or `"ALL=(ALL) ALL"` (password required)
- `{{SSH_ALLOW_AGENT_FORWARDING}}`: `"yes"` or `"no"`
- `{{SSH_ALLOW_TCP_FORWARDING}}`: `"yes"` or `"no"`
- `{{SYSCTL_IP_FORWARDING}}`: `0` (disabled) or `1` (enabled)
- `{{SYSCTL_DISABLE_IPV6}}`: `0` (IPv6 enabled) or `1` (IPv6 disabled)
- `{{SYSCTL_IPV6_ACCEPT_RA}}`: `0` (no RA) or `1` (accept RA)

## Example Configuration

For a secure production server:
```
{{ADMIN_SUDO_CONFIG}} = ALL=(ALL) ALL
{{SSH_ALLOW_AGENT_FORWARDING}} = no
{{SSH_ALLOW_TCP_FORWARDING}} = no
{{SYSCTL_IP_FORWARDING}} = 0
{{SYSCTL_DISABLE_IPV6}} = 1
```

For a development server with more flexibility:
```
{{ADMIN_SUDO_CONFIG}} = ALL=(ALL) NOPASSWD:ALL
{{SSH_ALLOW_AGENT_FORWARDING}} = yes
{{SSH_ALLOW_TCP_FORWARDING}} = yes
{{SYSCTL_IP_FORWARDING}} = 0
{{SYSCTL_DISABLE_IPV6}} = 0
```

## Post-Deployment

After cloud-init completes, complete the hardening with:
```bash
curl -sSL https://raw.githubusercontent.com/crxnit/Linux-Base-Setup-2026/main/install.sh | sudo bash
sudo ./harden.sh --skip-users --skip-ssh-basic
```

This adds CrowdSec IPS, auditd, rkhunter, SSH 2FA, and firewall rules.

## Validation

Validate your configuration:
```bash
cloud-init schema --config-file my-cloud-init.yaml
```

## Troubleshooting

Check logs on the deployed server:
```bash
# Cloud-init output
cat /var/log/cloud-init-output.log

# Our enhanced completion log
cat /var/log/cloud-init-hardening.log

# System detection info
cat /etc/linux-base-setup/system-info
```