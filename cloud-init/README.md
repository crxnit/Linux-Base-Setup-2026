# Cloud-Init Integration

Generate cloud-init configurations for first-boot server hardening on cloud platforms.

## Overview

Cloud-init handles security hardening that should happen **before SSH is accessible**:

| Component | Cloud-Init | harden.sh |
|-----------|:----------:|:---------:|
| Admin user + SSH keys | ✓ | - |
| Hostname/timezone | ✓ | - |
| Essential packages | ✓ | - |
| Sysctl kernel hardening | ✓ | - |
| SSH hardening (no 2FA) | ✓ | - |
| NTP configuration | ✓ | - |
| Disable uncommon protocols | ✓ | - |
| SSH 2FA (TOTP) | - | ✓ |
| CrowdSec IPS | - | ✓ |
| Auditd | - | ✓ |
| RKHunter | - | ✓ |
| Firewall rules | - | ✓ |
| Unattended upgrades | - | ✓ |

## Usage

### Option 1: Generator Script (Recommended)

Generate from your existing configuration:

```bash
# Generate to stdout
./generate-cloud-init.sh -f ~/.ssh/id_ed25519.pub -u myadmin

# Generate to file
./generate-cloud-init.sh \
  -c ../config/custom.conf \
  -f ~/.ssh/id_ed25519.pub \
  -t America/New_York \
  -o my-cloud-init.yaml
```

**Options:**

| Flag | Description |
|------|-------------|
| `-c, --config FILE` | Configuration file (default: config/default.conf) |
| `-o, --output FILE` | Output file (default: stdout) |
| `-k, --ssh-key KEY` | SSH public key string |
| `-f, --ssh-key-file FILE` | Path to SSH public key file |
| `-u, --username NAME` | Admin username |
| `-t, --timezone TZ` | Timezone (e.g., America/New_York) |

### Option 2: Manual Template

Copy and edit the template:

```bash
cp cloud-init.yaml.template my-cloud-init.yaml
# Edit and replace {{PLACEHOLDER}} values
```

## Cloud Provider Usage

### AWS EC2

```bash
# Via AWS CLI
aws ec2 run-instances \
  --image-id ami-xxxxx \
  --user-data file://my-cloud-init.yaml \
  ...

# Or paste into "User data" field in console
```

### DigitalOcean

```bash
# Via doctl
doctl compute droplet create myserver \
  --user-data-file my-cloud-init.yaml \
  ...

# Or paste into "User data" field in console
```

### Vultr

```bash
# Via vultr-cli
vultr-cli instance create \
  --userdata "$(cat my-cloud-init.yaml)" \
  ...
```

### Hetzner Cloud

```bash
# Via hcloud
hcloud server create \
  --user-data-from-file my-cloud-init.yaml \
  ...
```

### Linode

Use the StackScripts feature or paste into "User Data" field.

### Proxmox/Local VMs

```bash
# Create a cloud-init disk
qm set <vmid> --cicustom "user=local:snippets/my-cloud-init.yaml"
```

## Validation

Validate your cloud-init configuration:

```bash
# If cloud-init is installed locally
cloud-init schema --config-file my-cloud-init.yaml

# Or use an online validator
# https://cloudinit.readthedocs.io/en/latest/topics/debugging.html
```

## Post-Boot Hardening

After the server boots, complete hardening with:

```bash
# Install harden.sh
curl -sSL https://raw.githubusercontent.com/crxnit/Linux-Base-Setup-2026/main/install.sh | sudo bash

# Run remaining hardening (skip what cloud-init already did)
sudo harden
```

Cloud-init creates a marker at `/etc/linux-base-setup/cloud-init-completed` indicating which components were configured.

## SSH Port Change

If you change the SSH port in cloud-init (default: 22), remember to:

1. Update your cloud provider's firewall/security group
2. Connect with: `ssh -p <PORT> <USER>@<IP>`

## Troubleshooting

Check cloud-init logs on the server:

```bash
# Cloud-init output
cat /var/log/cloud-init-output.log

# Cloud-init status
cloud-init status --long

# Our completion log
cat /var/log/cloud-init-hardening.log
```
