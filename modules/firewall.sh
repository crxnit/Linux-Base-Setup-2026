#!/bin/bash
# ============================================================================
# Firewall Configuration Module
# ============================================================================
# Functions for configuring UFW or firewalld
# ============================================================================

configure_firewall() {
    log_section "Firewall Configuration"
    
    if [[ "$CONFIGURE_FIREWALL" != "true" ]]; then
        log_info "Firewall configuration disabled"
        return 0
    fi
    
    case "$FIREWALL_TYPE" in
        ufw)
            configure_ufw
            ;;
        firewalld)
            configure_firewalld
            ;;
        none)
            log_info "Firewall configuration set to 'none'"
            ;;
        *)
            log_warning "Unknown firewall type: $FIREWALL_TYPE"
            return 1
            ;;
    esac
}

configure_ufw() {
    log_info "Configuring UFW (Uncomplicated Firewall)"
    
    # Install UFW
    install_package "ufw"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure UFW with:"
        log_info "  Default incoming: $UFW_DEFAULT_INCOMING"
        log_info "  Default outgoing: $UFW_DEFAULT_OUTGOING"
        log_info "  Allowed ports: $UFW_ALLOWED_PORTS"
        log_info "  SSH port: $SSH_PORT"
        return 0
    fi
    
    # Disable UFW first to prevent lockouts
    ufw --force disable >> "$LOG_FILE" 2>&1
    
    # Reset to defaults
    log_info "Resetting UFW to defaults"
    ufw --force reset >> "$LOG_FILE" 2>&1
    
    # Set default policies
    log_info "Setting default policies"
    ufw default "$UFW_DEFAULT_INCOMING" incoming >> "$LOG_FILE" 2>&1
    ufw default "$UFW_DEFAULT_OUTGOING" outgoing >> "$LOG_FILE" 2>&1
    
    # CRITICAL: Allow SSH port FIRST
    log_info "Allowing SSH port: $SSH_PORT"
    ufw allow "$SSH_PORT/tcp" comment 'SSH' >> "$LOG_FILE" 2>&1
    
    # Allow other configured ports
    IFS=',' read -ra ports <<< "$UFW_ALLOWED_PORTS"
    for port_spec in "${ports[@]}"; do
        # Skip if it's the SSH port (already added)
        if [[ "$port_spec" == "$SSH_PORT/tcp" ]] || [[ "$port_spec" == "$SSH_PORT" ]]; then
            continue
        fi
        
        log_info "Allowing port: $port_spec"
        ufw allow "$port_spec" >> "$LOG_FILE" 2>&1
    done
    
    # Enable logging
    ufw logging low >> "$LOG_FILE" 2>&1
    
    # Enable UFW
    log_warning "Enabling UFW firewall"
    ufw --force enable >> "$LOG_FILE" 2>&1
    
    # Display status
    log_success "UFW firewall configured and enabled"
    ufw status verbose | tee -a "$LOG_FILE"
    
    return 0
}

configure_firewalld() {
    log_info "Configuring firewalld"
    
    # Install firewalld
    install_package "firewalld"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure firewalld"
        return 0
    fi
    
    # Start and enable firewalld
    systemctl start firewalld >> "$LOG_FILE" 2>&1
    systemctl enable firewalld >> "$LOG_FILE" 2>&1
    
    # Set default zone
    firewall-cmd --set-default-zone=public >> "$LOG_FILE" 2>&1
    
    # Allow SSH port
    log_info "Allowing SSH port: $SSH_PORT"
    firewall-cmd --permanent --add-port="$SSH_PORT/tcp" >> "$LOG_FILE" 2>&1
    
    # Allow other configured ports
    IFS=',' read -ra ports <<< "$UFW_ALLOWED_PORTS"
    for port_spec in "${ports[@]}"; do
        if [[ "$port_spec" == "$SSH_PORT/tcp" ]] || [[ "$port_spec" == "$SSH_PORT" ]]; then
            continue
        fi
        
        log_info "Allowing port: $port_spec"
        firewall-cmd --permanent --add-port="$port_spec" >> "$LOG_FILE" 2>&1
    done
    
    # Reload firewalld
    firewall-cmd --reload >> "$LOG_FILE" 2>&1
    
    # Display status
    log_success "Firewalld configured and enabled"
    firewall-cmd --list-all | tee -a "$LOG_FILE"
    
    return 0
}

add_firewall_rule() {
    local port="$1"
    local protocol="${2:-tcp}"
    local comment="${3:-}"
    
    if [[ "$FIREWALL_TYPE" == "ufw" ]]; then
        if [[ -n "$comment" ]]; then
            ufw allow "$port/$protocol" comment "$comment" >> "$LOG_FILE" 2>&1
        else
            ufw allow "$port/$protocol" >> "$LOG_FILE" 2>&1
        fi
        log_info "Added UFW rule: $port/$protocol"
    elif [[ "$FIREWALL_TYPE" == "firewalld" ]]; then
        firewall-cmd --permanent --add-port="$port/$protocol" >> "$LOG_FILE" 2>&1
        firewall-cmd --reload >> "$LOG_FILE" 2>&1
        log_info "Added firewalld rule: $port/$protocol"
    else
        log_warning "No firewall configured, skipping rule addition"
    fi
}

remove_firewall_rule() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    if [[ "$FIREWALL_TYPE" == "ufw" ]]; then
        ufw delete allow "$port/$protocol" >> "$LOG_FILE" 2>&1
        log_info "Removed UFW rule: $port/$protocol"
    elif [[ "$FIREWALL_TYPE" == "firewalld" ]]; then
        firewall-cmd --permanent --remove-port="$port/$protocol" >> "$LOG_FILE" 2>&1
        firewall-cmd --reload >> "$LOG_FILE" 2>&1
        log_info "Removed firewalld rule: $port/$protocol"
    else
        log_warning "No firewall configured, skipping rule removal"
    fi
}

configure_rate_limiting() {
    log_section "Firewall Rate Limiting"
    
    if [[ "$FIREWALL_TYPE" != "ufw" ]]; then
        log_info "Rate limiting only available with UFW"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure rate limiting for SSH"
        return 0
    fi
    
    log_info "Configuring rate limiting for SSH connections"
    
    # Remove existing SSH rule
    ufw delete allow "$SSH_PORT/tcp" >> "$LOG_FILE" 2>&1
    
    # Add rate-limited SSH rule (max 6 connections per 30 seconds)
    ufw limit "$SSH_PORT/tcp" comment 'SSH with rate limiting' >> "$LOG_FILE" 2>&1
    
    log_success "SSH rate limiting enabled"
    
    return 0
}
