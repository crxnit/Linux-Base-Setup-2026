#!/bin/bash
# =============================================================================
# DOCKER HOST HARDENING VERIFICATION SCRIPT
# =============================================================================
# Save as: verify-hardening.sh
# Usage: sudo ./verify-hardening.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo ""
    echo -e "${YELLOW}--- $1 ---${NC}"
}

check_sysctl() {
    local key="$1"
    local expected="$2"
    local description="$3"
    local actual
    
    if actual=$(sysctl -n "$key" 2>/dev/null); then
        actual=$(echo "$actual" | tr '\t' ' ' | tr -s ' ')
        expected=$(echo "$expected" | tr '\t' ' ' | tr -s ' ')
        
        if [[ "$actual" == "$expected" ]]; then
            echo -e "${GREEN}[PASS]${NC} $key = $actual"
            ((PASS++))
        else
            echo -e "${RED}[FAIL]${NC} $key = $actual (expected: $expected)"
            echo -e "       ${description}"
            ((FAIL++))
        fi
    else
        echo -e "${RED}[FAIL]${NC} $key - Unable to read"
        ((FAIL++))
    fi
}

check_module() {
    local module="$1"
    local description="$2"
    
    if lsmod | grep -q "^$module"; then
        echo -e "${GREEN}[PASS]${NC} Module '$module' is loaded"
        ((PASS++))
    else
        echo -e "${RED}[FAIL]${NC} Module '$module' is NOT loaded"
        echo -e "       ${description}"
        ((FAIL++))
    fi
}

# =============================================================================
# MAIN VERIFICATION
# =============================================================================

print_header "DOCKER HOST HARDENING VERIFICATION"
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"

print_section "KERNEL MODULES"
check_module "br_netfilter" "Required for Docker bridge networking"
check_module "nf_conntrack" "Required for connection tracking"

print_section "IP FORWARDING"
check_sysctl "net.ipv4.ip_forward" "1" "Required for Docker"

print_section "SOURCE ROUTING"
check_sysctl "net.ipv4.conf.all.accept_source_route" "0" "Security"
check_sysctl "net.ipv4.conf.default.accept_source_route" "0" "Security"

print_section "ICMP REDIRECTS"
check_sysctl "net.ipv4.conf.all.accept_redirects" "0" "Security"
check_sysctl "net.ipv4.conf.default.accept_redirects" "0" "Security"
check_sysctl "net.ipv4.conf.all.secure_redirects" "0" "Security"
check_sysctl "net.ipv4.conf.default.secure_redirects" "0" "Security"
check_sysctl "net.ipv4.conf.all.send_redirects" "0" "Security"
check_sysctl "net.ipv4.conf.default.send_redirects" "0" "Security"

print_section "REVERSE PATH FILTERING"
check_sysctl "net.ipv4.conf.all.rp_filter" "2" "Loose mode for Docker"
check_sysctl "net.ipv4.conf.default.rp_filter" "2" "Loose mode for Docker"

print_section "MARTIAN LOGGING"
check_sysctl "net.ipv4.conf.all.log_martians" "1" "Security"
check_sysctl "net.ipv4.conf.default.log_martians" "1" "Security"

print_section "SYN FLOOD PROTECTION"
check_sysctl "net.ipv4.tcp_syncookies" "1" "DDoS protection"
check_sysctl "net.ipv4.tcp_max_syn_backlog" "2048" "Queue size"
check_sysctl "net.ipv4.tcp_synack_retries" "2" "Retries"
check_sysctl "net.ipv4.tcp_syn_retries" "5" "Retries"

print_section "ICMP HARDENING"
check_sysctl "net.ipv4.icmp_echo_ignore_broadcasts" "1" "Security"
check_sysctl "net.ipv4.icmp_ignore_bogus_error_responses" "1" "Security"

print_section "KERNEL SECURITY"
check_sysctl "kernel.dmesg_restrict" "1" "Info disclosure"
check_sysctl "kernel.kptr_restrict" "1" "Info disclosure"
check_sysctl "kernel.randomize_va_space" "2" "ASLR"
check_sysctl "kernel.yama.ptrace_scope" "1" "Process isolation"
check_sysctl "kernel.panic" "10" "Recovery"
check_sysctl "kernel.panic_on_oops" "1" "Recovery"
check_sysctl "fs.suid_dumpable" "0" "Security"

print_section "NETWORK BUFFERS"
check_sysctl "net.core.rmem_max" "134217728" "Performance"
check_sysctl "net.core.wmem_max" "134217728" "Performance"
check_sysctl "net.core.rmem_default" "67108864" "Performance"
check_sysctl "net.core.wmem_default" "67108864" "Performance"
check_sysctl "net.core.netdev_max_backlog" "5000" "Performance"
check_sysctl "net.core.somaxconn" "4096" "Performance"

print_section "TCP BUFFERS"
check_sysctl "net.ipv4.tcp_rmem" "4096 87380 134217728" "Performance"
check_sysctl "net.ipv4.tcp_wmem" "4096 65536 134217728" "Performance"

print_section "IPV6 DISABLED"
check_sysctl "net.ipv6.conf.all.disable_ipv6" "1" "IPv6 disabled"
check_sysctl "net.ipv6.conf.default.disable_ipv6" "1" "IPv6 disabled"
check_sysctl "net.ipv6.conf.lo.disable_ipv6" "1" "IPv6 disabled"

print_section "FILESYSTEM PROTECTION"
check_sysctl "fs.protected_hardlinks" "1" "Security"
check_sysctl "fs.protected_symlinks" "1" "Security"
check_sysctl "fs.protected_fifos" "2" "Security"
check_sysctl "fs.protected_regular" "2" "Security"

print_section "BRIDGE NETWORKING"
check_sysctl "net.bridge.bridge-nf-call-iptables" "1" "Docker networking"

print_section "CONNECTION TRACKING"
check_sysctl "net.netfilter.nf_conntrack_max" "262144" "Capacity"
check_sysctl "net.netfilter.nf_conntrack_tcp_timeout_established" "86400" "Timeout"
check_sysctl "net.netfilter.nf_conntrack_tcp_timeout_time_wait" "30" "Timeout"

print_section "EPHEMERAL PORTS"
check_sysctl "net.ipv4.ip_local_port_range" "1024 65535" "Port range"

print_section "TCP KEEPALIVE"
check_sysctl "net.ipv4.tcp_keepalive_time" "600" "Keepalive"
check_sysctl "net.ipv4.tcp_keepalive_intvl" "60" "Keepalive"
check_sysctl "net.ipv4.tcp_keepalive_probes" "5" "Keepalive"

print_section "TIME_WAIT"
check_sysctl "net.ipv4.tcp_tw_reuse" "1" "Socket reuse"
check_sysctl "net.ipv4.tcp_fin_timeout" "15" "Cleanup"

print_section "GRUB IPv6"
if grep -q "ipv6.disable=1" /proc/cmdline 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Booted with ipv6.disable=1"
    ((PASS++))
else
    echo -e "${YELLOW}[WARN]${NC} Not booted with ipv6.disable=1 (reboot may be required)"
    ((WARN++))
fi

print_section "DOCKER"
if systemctl is-active --quiet docker 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Docker is running"
    ((PASS++))
    
    if [[ -f /etc/docker/daemon.json ]]; then
        if command -v jq &>/dev/null; then
            if jq -e '.ipv6 == false' /etc/docker/daemon.json &>/dev/null; then
                echo -e "${GREEN}[PASS]${NC} Docker IPv6 is disabled"
                ((PASS++))
            else
                echo -e "${YELLOW}[WARN]${NC} Docker IPv6 setting not found or not false"
                ((WARN++))
            fi
        fi
    fi
else
    echo -e "${YELLOW}[WARN]${NC} Docker is not running"
    ((WARN++))
fi

# =============================================================================
# SUMMARY
# =============================================================================

print_header "SUMMARY"
echo ""
echo -e "  ${GREEN}PASSED:${NC}   $PASS"
echo -e "  ${RED}FAILED:${NC}   $FAIL"
echo -e "  ${YELLOW}WARNINGS:${NC} $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    [[ $WARN -gt 0 ]] && echo -e "${YELLOW}  Review warnings above${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    exit 1
fi