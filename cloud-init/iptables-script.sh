#!/bin/bash
# =============================================================================
# IPTABLES FIREWALL FOR DOCKER WEB SERVER
# =============================================================================
# This script configures iptables for a Docker host running Traefik
# 
# Allowed Incoming:
#   - TCP 80 (HTTP)
#   - TCP 443 (HTTPS)
#   - TCP 22 (SSH default)
#   - TCP 4444 (SSH alternate)
#
# Features:
#   - Stateful packet inspection
#   - SSH brute-force protection (rate limiting)
#   - Logging of dropped packets
#   - Docker-compatible (preserves Docker chains)
#   - Anti-spoofing rules
#   - ICMP rate limiting
#
# Usage: sudo ./iptables-firewall.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Allowed TCP ports for incoming connections
ALLOWED_TCP_PORTS="80 443 22 4444"

# SSH ports (for rate limiting)
SSH_PORTS="22 4444"

# Rate limits
SSH_RATE_LIMIT="4/minute"
SSH_RATE_BURST="8"
ICMP_RATE_LIMIT="10/second"
ICMP_RATE_BURST="20"
LOG_RATE_LIMIT="5/minute"
LOG_RATE_BURST="10"

# Logging prefix
LOG_PREFIX="IPT-DROPPED: "

# Docker bridge network (adjust if you changed Docker's default)
DOCKER_BRIDGE="172.16.0.0/12"

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

backup_rules() {
    local backup_file="/root/iptables-backup-$(date +%Y%m%d-%H%M%S).rules"
    iptables-save > "$backup_file"
    log_info "Current rules backed up to: $backup_file"
}

# -----------------------------------------------------------------------------
# MAIN FIREWALL CONFIGURATION
# -----------------------------------------------------------------------------

configure_firewall() {
    log_info "Configuring iptables firewall..."

    # =========================================================================
    # FLUSH EXISTING RULES (Carefully - preserve Docker chains)
    # =========================================================================
    
    log_info "Flushing existing rules (preserving Docker chains)..."
    
    # Flush INPUT and OUTPUT chains
    iptables -F INPUT
    iptables -F OUTPUT
    
    # Flush custom chains if they exist (but not Docker chains)
    iptables -F LOGGING 2>/dev/null || true
    iptables -F SSH_RATE_LIMIT 2>/dev/null || true
    
    # Delete custom chains
    iptables -X LOGGING 2>/dev/null || true
    iptables -X SSH_RATE_LIMIT 2>/dev/null || true

    # =========================================================================
    # SET DEFAULT POLICIES
    # =========================================================================
    
    log_info "Setting default policies..."
    
    # Default DROP for incoming, ACCEPT for outgoing
    # FORWARD is managed by Docker - leave as ACCEPT (Docker handles filtering)
    iptables -P INPUT DROP
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    # =========================================================================
    # CREATE CUSTOM CHAINS
    # =========================================================================
    
    log_info "Creating custom chains..."
    
    # Logging chain for dropped packets
    iptables -N LOGGING
    iptables -A LOGGING -m limit --limit $LOG_RATE_LIMIT --limit-burst $LOG_RATE_BURST \
        -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
    iptables -A LOGGING -j DROP
    
    # SSH rate limiting chain
    iptables -N SSH_RATE_LIMIT
    iptables -A SSH_RATE_LIMIT -m conntrack --ctstate NEW \
        -m recent --set --name SSH --rsource
    iptables -A SSH_RATE_LIMIT -m conntrack --ctstate NEW \
        -m recent --update --seconds 60 --hitcount 10 --name SSH --rsource \
        -j DROP
    iptables -A SSH_RATE_LIMIT -j ACCEPT

    # =========================================================================
    # LOOPBACK RULES
    # =========================================================================
    
    log_info "Configuring loopback rules..."
    
    # Allow all loopback traffic
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Drop packets claiming to be from loopback on non-loopback interfaces
    iptables -A INPUT ! -i lo -s 127.0.0.0/8 -j DROP

    # =========================================================================
    # STATEFUL PACKET INSPECTION
    # =========================================================================
    
    log_info "Configuring stateful inspection..."
    
    # Allow established and related connections (critical for performance)
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Drop invalid packets
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

    # =========================================================================
    # ANTI-SPOOFING RULES
    # =========================================================================
    
    log_info "Configuring anti-spoofing rules..."
    
    # Drop packets with impossible source addresses
    # RFC 1918 private addresses from public interfaces would be handled by rp_filter
    # These are additional protections
    
    # Drop NULL packets (TCP with no flags)
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    
    # Drop XMAS packets (TCP with all flags)
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    
    # Drop SYN-FIN packets (invalid combination)
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    
    # Drop SYN-RST packets (invalid combination)
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    
    # Drop FIN without ACK
    iptables -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
    
    # Drop PSH without ACK
    iptables -A INPUT -p tcp --tcp-flags PSH,ACK PSH -j DROP
    
    # Drop URG without ACK
    iptables -A INPUT -p tcp --tcp-flags URG,ACK URG -j DROP
    
    # Drop fragments (can be used for attacks)
    iptables -A INPUT -f -j DROP

    # =========================================================================
    # ICMP RULES
    # =========================================================================
    
    log_info "Configuring ICMP rules..."
    
    # Allow essential ICMP with rate limiting
    # Echo request (ping) - rate limited
    iptables -A INPUT -p icmp --icmp-type echo-request \
        -m limit --limit $ICMP_RATE_LIMIT --limit-burst $ICMP_RATE_BURST -j ACCEPT
    
    # Echo reply
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
    
    # Destination unreachable (needed for path MTU discovery)
    iptables -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
    
    # Time exceeded (needed for traceroute)
    iptables -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
    
    # Parameter problem
    iptables -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT

    # =========================================================================
    # DOCKER BRIDGE TRAFFIC
    # =========================================================================
    
    log_info "Configuring Docker bridge rules..."
    
    # Allow traffic from Docker containers to host services
    # This allows containers to reach services on the host
    iptables -A INPUT -i docker0 -j ACCEPT
    
    # Allow traffic from Docker custom bridge networks (br-*)
    iptables -A INPUT -i br-+ -j ACCEPT

    # =========================================================================
    # SSH RULES (with rate limiting)
    # =========================================================================
    
    log_info "Configuring SSH rules..."
    
    for port in $SSH_PORTS; do
        # New SSH connections go through rate limiting
        iptables -A INPUT -p tcp --dport "$port" -m conntrack --ctstate NEW \
            -j SSH_RATE_LIMIT
    done

    # =========================================================================
    # WEB SERVER RULES
    # =========================================================================
    
    log_info "Configuring web server rules..."
    
    # HTTP
    iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
    
    # HTTPS
    iptables -A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT

    # =========================================================================
    # DOCKER-USER CHAIN (for filtering container traffic)
    # =========================================================================
    
    log_info "Configuring DOCKER-USER chain..."
    
    # Docker creates this chain - we add rules to it for container traffic filtering
    # These rules apply to traffic forwarded to/from containers
    
    # Ensure chain exists (Docker should create it, but just in case)
    iptables -N DOCKER-USER 2>/dev/null || true
    
    # Flush existing rules in DOCKER-USER
    iptables -F DOCKER-USER
    
    # Allow established/related (performance optimization)
    iptables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
    
    # Allow traffic to container ports 80 and 443 (Traefik)
    iptables -A DOCKER-USER -p tcp --dport 80 -j RETURN
    iptables -A DOCKER-USER -p tcp --dport 443 -j RETURN
    
    # Allow internal Docker network traffic
    iptables -A DOCKER-USER -i docker0 -o docker0 -j RETURN
    iptables -A DOCKER-USER -i br-+ -o br-+ -j RETURN
    
    # Allow container-to-container across networks
    iptables -A DOCKER-USER -i docker0 -o br-+ -j RETURN
    iptables -A DOCKER-USER -i br-+ -o docker0 -j RETURN
    iptables -A DOCKER-USER -i br-+ -o br-+ -j RETURN
    
    # Return for all other traffic (let Docker's rules handle it)
    # Change to DROP if you want to restrict container outbound access
    iptables -A DOCKER-USER -j RETURN

    # =========================================================================
    # FINAL DROP RULE WITH LOGGING
    # =========================================================================
    
    log_info "Configuring final drop rule..."
    
    # Send all other INPUT traffic to logging chain (which drops after logging)
    iptables -A INPUT -j LOGGING

    # =========================================================================
    # COMPLETE
    # =========================================================================
    
    log_info "Firewall configuration complete!"
}

# -----------------------------------------------------------------------------
# SAVE RULES FOR PERSISTENCE
# -----------------------------------------------------------------------------

save_rules() {
    log_info "Saving rules for persistence..."
    
    # Try iptables-persistent first (Debian/Ubuntu)
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save
        log_info "Rules saved via netfilter-persistent"
    # Try iptables-services (RHEL/CentOS)
    elif command -v service &>/dev/null && [[ -f /etc/sysconfig/iptables ]]; then
        service iptables save
        log_info "Rules saved via iptables-services"
    # Fallback: save to file
    else
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
        log_info "Rules saved to /etc/iptables/rules.v4"
    fi
}

# -----------------------------------------------------------------------------
# DISPLAY RULES
# -----------------------------------------------------------------------------

display_rules() {
    echo ""
    echo "=========================================="
    echo "CURRENT IPTABLES RULES"
    echo "=========================================="
    iptables -L -n -v --line-numbers
    echo ""
    echo "=========================================="
    echo "NAT TABLE (Docker)"
    echo "=========================================="
    iptables -t nat -L -n -v --line-numbers
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------

main() {
    check_root
    
    echo "=========================================="
    echo "Docker Web Server Firewall Setup"
    echo "=========================================="
    echo ""
    echo "This will configure iptables with:"
    echo "  - Allowed: TCP 80, 443 (HTTP/HTTPS)"
    echo "  - Allowed: TCP 22, 4444 (SSH)"
    echo "  - SSH rate limiting"
    echo "  - Docker bridge traffic"
    echo "  - Logging of dropped packets"
    echo ""
    
    # Backup existing rules
    backup_rules
    
    # Configure firewall
    configure_firewall
    
    # Save rules
    save_rules
    
    # Display results
    display_rules
    
    echo ""
    log_info "Firewall setup complete!"
    echo ""
    echo "Verify with: sudo iptables -L -n -v"
    echo "Check logs:  sudo journalctl -k | grep IPT-DROPPED"
    echo ""
}

# Run main function
main "$@"