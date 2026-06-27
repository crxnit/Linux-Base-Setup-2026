#!/bin/bash
# =============================================================================
# DISABLE ALTERNATIVE FIREWALLS - IPTABLES ONLY
# =============================================================================
# This script disables and removes UFW, nftables, firewalld, and other
# firewall management tools to ensure iptables is the sole firewall.
#
# Supported distributions:
#   - Ubuntu 20.04/22.04/24.04
#   - Debian 11/12
#   - RHEL/CentOS/Rocky/Alma 8/9
#
# Usage: sudo ./disable-alternative-firewalls.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

LOG_FILE="/var/log/firewall-cleanup.log"
BACKUP_DIR="/root/firewall-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
}

log_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_FAMILY=""
        
        case "$DISTRO" in
            ubuntu|debian|linuxmint|pop)
                DISTRO_FAMILY="debian"
                PKG_MANAGER="apt"
                ;;
            rhel|centos|rocky|almalinux|fedora|ol)
                DISTRO_FAMILY="rhel"
                if command -v dnf &>/dev/null; then
                    PKG_MANAGER="dnf"
                else
                    PKG_MANAGER="yum"
                fi
                ;;
            *)
                DISTRO_FAMILY="unknown"
                PKG_MANAGER="unknown"
                ;;
        esac
        
        log_info "Detected: $DISTRO $DISTRO_VERSION (family: $DISTRO_FAMILY)"
    else
        log_error "Cannot detect distribution"
        exit 1
    fi
}

create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log_info "Backup directory: $BACKUP_DIR"
}

# -----------------------------------------------------------------------------
# SERVICE MANAGEMENT FUNCTIONS
# -----------------------------------------------------------------------------

service_exists() {
    local service="$1"
    systemctl list-unit-files "$service.service" &>/dev/null || \
    systemctl list-units --all "$service.service" &>/dev/null || \
    [[ -f "/etc/systemd/system/$service.service" ]] || \
    [[ -f "/lib/systemd/system/$service.service" ]] || \
    [[ -f "/usr/lib/systemd/system/$service.service" ]]
}

stop_and_disable_service() {
    local service="$1"
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        log_info "Stopping $service..."
        systemctl stop "$service" || log_warn "Failed to stop $service"
    fi
    
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        log_info "Disabling $service..."
        systemctl disable "$service" || log_warn "Failed to disable $service"
    fi
    
    # Mask the service to prevent it from starting
    log_info "Masking $service..."
    systemctl mask "$service" 2>/dev/null || log_warn "Failed to mask $service"
}

package_installed() {
    local package="$1"
    
    case "$PKG_MANAGER" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        dnf|yum)
            rpm -q "$package" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

remove_package() {
    local package="$1"
    
    if package_installed "$package"; then
        log_info "Removing package: $package"
        
        case "$PKG_MANAGER" in
            apt)
                DEBIAN_FRONTEND=noninteractive apt-get remove -y "$package" || log_warn "Failed to remove $package"
                ;;
            dnf)
                dnf remove -y "$package" || log_warn "Failed to remove $package"
                ;;
            yum)
                yum remove -y "$package" || log_warn "Failed to remove $package"
                ;;
        esac
    else
        log_info "Package not installed: $package"
    fi
}

purge_package() {
    local package="$1"
    
    if package_installed "$package"; then
        log_info "Purging package: $package"
        
        case "$PKG_MANAGER" in
            apt)
                DEBIAN_FRONTEND=noninteractive apt-get purge -y "$package" || log_warn "Failed to purge $package"
                ;;
            dnf|yum)
                # RPM-based systems don't have purge, remove is sufficient
                remove_package "$package"
                ;;
        esac
    fi
}

# -----------------------------------------------------------------------------
# UFW (Uncomplicated Firewall)
# -----------------------------------------------------------------------------

disable_ufw() {
    log_section "UFW (Uncomplicated Firewall)"
    
    if command -v ufw &>/dev/null; then
        log_info "UFW found, disabling..."
        
        # Backup UFW rules
        if [[ -d /etc/ufw ]]; then
            log_info "Backing up UFW configuration..."
            cp -r /etc/ufw "$BACKUP_DIR/" 2>/dev/null || true
        fi
        
        # Disable UFW
        ufw disable 2>/dev/null || true
        
        # Stop and disable service
        stop_and_disable_service "ufw"
        
        # Remove package
        purge_package "ufw"
        
        # Clean up remaining files
        rm -rf /etc/ufw 2>/dev/null || true
        rm -f /etc/default/ufw 2>/dev/null || true
        
        log_info "UFW disabled and removed"
    else
        log_info "UFW not installed, skipping"
    fi
}

# -----------------------------------------------------------------------------
# NFTABLES
# -----------------------------------------------------------------------------

disable_nftables() {
    log_section "nftables"
    
    if command -v nft &>/dev/null; then
        log_info "nftables found, disabling..."
        
        # Backup nftables rules
        if nft list ruleset &>/dev/null; then
            log_info "Backing up nftables ruleset..."
            nft list ruleset > "$BACKUP_DIR/nftables-backup.conf" 2>/dev/null || true
        fi
        
        # Backup config files
        [[ -f /etc/nftables.conf ]] && cp /etc/nftables.conf "$BACKUP_DIR/" 2>/dev/null || true
        [[ -d /etc/nftables ]] && cp -r /etc/nftables "$BACKUP_DIR/" 2>/dev/null || true
        
        # Flush all nftables rules
        log_info "Flushing nftables ruleset..."
        nft flush ruleset 2>/dev/null || true
        
        # Stop and disable service
        stop_and_disable_service "nftables"
        
        # Remove package (be careful - some systems need it)
        # We'll keep the package but disable it, as iptables-nft may depend on it
        # purge_package "nftables"
        
        # Clear config to prevent rules loading on boot
        if [[ -f /etc/nftables.conf ]]; then
            log_info "Clearing nftables config..."
            echo "#!/usr/sbin/nft -f" > /etc/nftables.conf
            echo "# Disabled - using iptables" >> /etc/nftables.conf
            echo "flush ruleset" >> /etc/nftables.conf
        fi
        
        log_info "nftables disabled"
    else
        log_info "nftables not installed, skipping"
    fi
}

# -----------------------------------------------------------------------------
# FIREWALLD
# -----------------------------------------------------------------------------

disable_firewalld() {
    log_section "firewalld"
    
    if command -v firewall-cmd &>/dev/null || service_exists "firewalld"; then
        log_info "firewalld found, disabling..."
        
        # Backup firewalld configuration
        if [[ -d /etc/firewalld ]]; then
            log_info "Backing up firewalld configuration..."
            cp -r /etc/firewalld "$BACKUP_DIR/" 2>/dev/null || true
        fi
        
        # Stop and disable service
        stop_and_disable_service "firewalld"
        
        # Remove package
        purge_package "firewalld"
        
        # Clean up
        rm -rf /etc/firewalld 2>/dev/null || true
        
        log_info "firewalld disabled and removed"
    else
        log_info "firewalld not installed, skipping"
    fi
}

# -----------------------------------------------------------------------------
# IPTABLES-NFT (iptables using nftables backend)
# -----------------------------------------------------------------------------

switch_to_iptables_legacy() {
    log_section "iptables Backend Check"
    
    # Check if using iptables-nft
    if command -v iptables &>/dev/null; then
        local iptables_version
        iptables_version=$(iptables --version 2>/dev/null || echo "unknown")
        log_info "Current iptables: $iptables_version"
        
        if echo "$iptables_version" | grep -qi "nf_tables\|nft"; then
            log_warn "System is using iptables-nft (nftables backend)"
            
            # On Debian/Ubuntu, switch to legacy
            if [[ "$DISTRO_FAMILY" == "debian" ]]; then
                if command -v update-alternatives &>/dev/null; then
                    log_info "Switching to iptables-legacy..."
                    
                    # Install iptables if needed
                    if ! package_installed "iptables"; then
                        apt-get install -y iptables
                    fi
                    
                    # Check if legacy is available
                    if [[ -x /usr/sbin/iptables-legacy ]]; then
                        update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true
                        update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true
                        update-alternatives --set arptables /usr/sbin/arptables-legacy 2>/dev/null || true
                        update-alternatives --set ebtables /usr/sbin/ebtables-legacy 2>/dev/null || true
                        
                        log_info "Switched to iptables-legacy"
                    else
                        log_warn "iptables-legacy not available, keeping iptables-nft"
                        log_warn "This is fine - iptables commands will work, just using nftables kernel backend"
                    fi
                fi
            fi
        else
            log_info "Already using iptables-legacy or standard iptables"
        fi
    fi
}

# -----------------------------------------------------------------------------
# SHOREWALL
# -----------------------------------------------------------------------------

disable_shorewall() {
    log_section "Shorewall"
    
    if command -v shorewall &>/dev/null || service_exists "shorewall"; then
        log_info "Shorewall found, disabling..."
        
        # Backup Shorewall configuration
        if [[ -d /etc/shorewall ]]; then
            log_info "Backing up Shorewall configuration..."
            cp -r /etc/shorewall "$BACKUP_DIR/" 2>/dev/null || true
        fi
        
        # Stop and disable service
        stop_and_disable_service "shorewall"
        stop_and_disable_service "shorewall6"
        
        # Remove packages
        purge_package "shorewall"
        purge_package "shorewall6"
        purge_package "shorewall-core"
        
        log_info "Shorewall disabled and removed"
    else
        log_info "Shorewall not installed, skipping"
    fi
}

# -----------------------------------------------------------------------------
# CSF (ConfigServer Security & Firewall)
# -----------------------------------------------------------------------------

disable_csf() {
    log_section "CSF (ConfigServer Firewall)"
    
    if command -v csf &>/dev/null || [[ -d /etc/csf ]]; then
        log_info "CSF found, disabling..."
        
        # Backup CSF configuration
        if [[ -d /etc/csf ]]; then
            log_info "Backing up CSF configuration..."
            cp -r /etc/csf "$BACKUP_DIR/" 2>/dev/null || true
        fi
        
        # Disable CSF
        csf -x 2>/dev/null || true
        
        # Stop and disable services
        stop_and_disable_service "csf"
        stop_and_disable_service "lfd"
        
        # Uninstall CSF if uninstall script exists
        if [[ -x /etc/csf/uninstall.sh ]]; then
            log_info "Running CSF uninstall script..."
            /etc/csf/uninstall.sh 2>/dev/null || true
        fi
        
        # Clean up
        rm -rf /etc/csf 2>/dev/null || true
        rm -f /usr/sbin/csf 2>/dev/null || true
        rm -f /usr/sbin/lfd 2>/dev/null || true
        
        log_info "CSF disabled and removed"
    else
        log_info "CSF not installed, skipping"
    fi
}

# -----------------------------------------------------------------------------
# FAIL2BAN (Not a firewall, but manages iptables rules)
# -----------------------------------------------------------------------------

check_fail2ban() {
    log_section "Fail2ban Check"
    
    if command -v fail2ban-client &>/dev/null; then
        log_info "Fail2ban is installed"
        log_warn "Fail2ban manages iptables rules for intrusion prevention"
        log_warn "Keeping Fail2ban installed - it works WITH iptables"
        
        # Ensure fail2ban uses iptables, not nftables
        if [[ -f /etc/fail2ban/jail.local ]]; then
            if grep -q "banaction.*nftables" /etc/fail2ban/jail.local; then
                log_info "Updating Fail2ban to use iptables..."
                sed -i 's/banaction.*=.*nftables.*/banaction = iptables-multiport/g' /etc/fail2ban/jail.local
            fi
        fi
        
        if [[ -f /etc/fail2ban/jail.conf ]]; then
            log_info "Consider setting 'banaction = iptables-multiport' in jail.local"
        fi
    else
        log_info "Fail2ban not installed"
    fi
}

# -----------------------------------------------------------------------------
# DOCKER FIREWALL HANDLING
# -----------------------------------------------------------------------------

check_docker() {
    log_section "Docker Check"
    
    if command -v docker &>/dev/null; then
        log_info "Docker is installed"
        
        if systemctl is-active --quiet docker; then
            log_info "Docker is running - will preserve Docker iptables chains"
            log_warn "Docker manages its own iptables rules (DOCKER, DOCKER-USER chains)"
            log_warn "These will be preserved and should not be modified directly"
        fi
        
        # Check Docker's iptables setting
        if [[ -f /etc/docker/daemon.json ]]; then
            if grep -q '"iptables".*false' /etc/docker/daemon.json; then
                log_warn "Docker iptables is DISABLED in daemon.json"
                log_warn "This means Docker won't manage firewall rules for containers"
            fi
        fi
    else
        log_info "Docker not installed"
    fi
}

# -----------------------------------------------------------------------------
# INSTALL IPTABLES TOOLS
# -----------------------------------------------------------------------------

install_iptables() {
    log_section "Install iptables Tools"
    
    log_info "Ensuring iptables and related tools are installed..."
    
    case "$PKG_MANAGER" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                iptables \
                iptables-persistent \
                netfilter-persistent \
                conntrack \
                ipset
            ;;
        dnf)
            dnf install -y \
                iptables \
                iptables-services \
                conntrack-tools \
                ipset \
                ipset-service
            ;;
        yum)
            yum install -y \
                iptables \
                iptables-services \
                conntrack-tools \
                ipset \
                ipset-service
            ;;
    esac
    
    log_info "iptables tools installed"
}

# -----------------------------------------------------------------------------
# ENABLE IPTABLES PERSISTENCE
# -----------------------------------------------------------------------------

enable_iptables_persistence() {
    log_section "Enable iptables Persistence"
    
    case "$DISTRO_FAMILY" in
        debian)
            # Enable netfilter-persistent
            if service_exists "netfilter-persistent"; then
                systemctl enable netfilter-persistent
                log_info "Enabled netfilter-persistent service"
            fi
            ;;
        rhel)
            # Enable iptables-services
            if service_exists "iptables"; then
                systemctl enable iptables
                log_info "Enabled iptables service"
            fi
            ;;
    esac
}

# -----------------------------------------------------------------------------
# FINAL CLEANUP
# -----------------------------------------------------------------------------

cleanup() {
    log_section "Cleanup"
    
    # Reload systemd
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Clean package cache
    case "$PKG_MANAGER" in
        apt)
            apt-get autoremove -y
            apt-get clean
            ;;
        dnf)
            dnf autoremove -y
            dnf clean all
            ;;
        yum)
            yum autoremove -y
            yum clean all
            ;;
    esac
    
    log_info "Cleanup complete"
}

# -----------------------------------------------------------------------------
# VERIFICATION
# -----------------------------------------------------------------------------

verify_configuration() {
    log_section "Verification"
    
    local issues=0
    
    echo ""
    echo "Checking firewall status..."
    echo ""
    
    # Check UFW
    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            echo -e "${RED}[FAIL]${NC} UFW is still active"
            ((issues++))
        else
            echo -e "${GREEN}[PASS]${NC} UFW is disabled or removed"
        fi
    else
        echo -e "${GREEN}[PASS]${NC} UFW is not installed"
    fi
    
    # Check nftables
    if systemctl is-active --quiet nftables 2>/dev/null; then
        echo -e "${RED}[FAIL]${NC} nftables service is still active"
        ((issues++))
    else
        echo -e "${GREEN}[PASS]${NC} nftables service is not active"
    fi
    
    # Check firewalld
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        echo -e "${RED}[FAIL]${NC} firewalld is still active"
        ((issues++))
    else
        echo -e "${GREEN}[PASS]${NC} firewalld is not active"
    fi
    
    # Check shorewall
    if systemctl is-active --quiet shorewall 2>/dev/null; then
        echo -e "${RED}[FAIL]${NC} Shorewall is still active"
        ((issues++))
    else
        echo -e "${GREEN}[PASS]${NC} Shorewall is not active"
    fi
    
    # Check iptables is available
    if command -v iptables &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} iptables command is available"
        echo "       Version: $(iptables --version 2>/dev/null || echo 'unknown')"
    else
        echo -e "${RED}[FAIL]${NC} iptables command not found"
        ((issues++))
    fi
    
    # Check iptables can list rules
    if iptables -L -n &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} iptables can list rules"
        echo "       INPUT policy: $(iptables -L INPUT -n | head -1 | grep -oP '\(policy \K[A-Z]+')"
    else
        echo -e "${RED}[FAIL]${NC} iptables cannot list rules"
        ((issues++))
    fi
    
    echo ""
    
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✓ All checks passed - iptables is the only active firewall${NC}"
    else
        echo -e "${RED}✗ $issues issue(s) found - review the output above${NC}"
    fi
    
    return $issues
}

# -----------------------------------------------------------------------------
# GENERATE STATUS REPORT
# -----------------------------------------------------------------------------

generate_report() {
    local report_file="$BACKUP_DIR/firewall-cleanup-report.txt"
    
    {
        echo "=========================================="
        echo "FIREWALL CLEANUP REPORT"
        echo "=========================================="
        echo ""
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "Distribution: $DISTRO $DISTRO_VERSION"
        echo ""
        echo "=========================================="
        echo "SERVICES STATUS"
        echo "=========================================="
        echo ""
        
        for service in ufw nftables firewalld shorewall shorewall6 csf lfd; do
            status="not found"
            if service_exists "$service"; then
                if systemctl is-masked --quiet "$service" 2>/dev/null; then
                    status="masked"
                elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
                    if systemctl is-active --quiet "$service" 2>/dev/null; then
                        status="enabled, running"
                    else
                        status="enabled, stopped"
                    fi
                else
                    status="disabled"
                fi
            fi
            printf "%-20s %s\n" "$service:" "$status"
        done
        
        echo ""
        echo "=========================================="
        echo "IPTABLES STATUS"
        echo "=========================================="
        echo ""
        echo "Version: $(iptables --version 2>/dev/null || echo 'not installed')"
        echo ""
        echo "Current rules:"
        iptables -L -n -v 2>/dev/null || echo "Unable to list rules"
        
        echo ""
        echo "=========================================="
        echo "BACKUP LOCATION"
        echo "=========================================="
        echo ""
        echo "Configuration backups: $BACKUP_DIR"
        ls -la "$BACKUP_DIR" 2>/dev/null || echo "No backups created"
        
    } > "$report_file"
    
    log_info "Report saved to: $report_file"
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------

main() {
    echo ""
    echo "=========================================="
    echo "DISABLE ALTERNATIVE FIREWALLS"
    echo "=========================================="
    echo ""
    echo "This script will:"
    echo "  - Disable and remove UFW"
    echo "  - Disable nftables"
    echo "  - Disable and remove firewalld"
    echo "  - Disable and remove Shorewall"
    echo "  - Disable and remove CSF"
    echo "  - Install/verify iptables tools"
    echo "  - Configure iptables persistence"
    echo ""
    echo "Backups will be saved before removal."
    echo ""
    
    # Check root
    check_root
    
    # Initialize log
    echo "Firewall cleanup started at $(date)" > "$LOG_FILE"
    
    # Detect distribution
    detect_distro
    
    # Create backup directory
    create_backup_dir
    
    # Disable all alternative firewalls
    disable_ufw
    disable_nftables
    disable_firewalld
    disable_shorewall
    disable_csf
    
    # Check/switch iptables backend
    switch_to_iptables_legacy
    
    # Check fail2ban
    check_fail2ban
    
    # Check Docker
    check_docker
    
    # Install iptables tools
    install_iptables
    
    # Enable persistence
    enable_iptables_persistence
    
    # Cleanup
    cleanup
    
    # Generate report
    generate_report
    
    # Verify
    verify_configuration
    
    echo ""
    echo "=========================================="
    echo "COMPLETE"
    echo "=========================================="
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo "Log file: $LOG_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Configure iptables rules"
    echo "  2. Save rules: iptables-save > /etc/iptables/rules.v4"
    echo "  3. Verify persistence after reboot"
    echo ""
}

# Run main
main "$@"