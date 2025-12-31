#!/bin/bash
# ============================================================================
# User Management Module
# ============================================================================
# Functions for creating and managing administrative users
# ============================================================================

create_admin_user() {
    log_section "User Management"
    
    if [[ "$CREATE_ADMIN_USER" != "true" ]]; then
        log_info "User creation disabled in configuration"
        return 0
    fi
    
    # Get username
    if [[ -z "$ADMIN_USERNAME" ]]; then
        ADMIN_USERNAME=$(prompt_input "Enter new admin username" "" validate_username)
    fi
    
    # Check if user exists
    if id "$ADMIN_USERNAME" &>/dev/null; then
        log_warning "User $ADMIN_USERNAME already exists"
        
        # Check and add missing groups
        local missing_groups=()
        IFS=',' read -ra groups <<< "$ADMIN_USER_GROUPS"
        for group in "${groups[@]}"; do
            if ! groups "$ADMIN_USERNAME" | grep -q "\<$group\>"; then
                missing_groups+=("$group")
            fi
        done
        
        if [[ ${#missing_groups[@]} -gt 0 ]]; then
            log_info "Adding user to missing groups: ${missing_groups[*]}"
            if [[ "$DRY_RUN" != "true" ]]; then
                for group in "${missing_groups[@]}"; do
                    usermod -aG "$group" "$ADMIN_USERNAME"
                done
                log_success "Updated group memberships for $ADMIN_USERNAME"
            fi
        else
            log_info "User already has all required group memberships"
        fi
        
        return 0
    fi
    
    log_info "Creating new admin user: $ADMIN_USERNAME"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create user: $ADMIN_USERNAME"
        log_info "[DRY-RUN] Shell: $ADMIN_USER_SHELL"
        log_info "[DRY-RUN] Groups: $ADMIN_USER_GROUPS"
        return 0
    fi
    
    # Create user with home directory and specified shell
    if useradd -m -s "$ADMIN_USER_SHELL" -G "$ADMIN_USER_GROUPS" "$ADMIN_USERNAME" >> "$LOG_FILE" 2>&1; then
        log_success "Created user: $ADMIN_USERNAME"
    else
        log_error "Failed to create user: $ADMIN_USERNAME"
        return 1
    fi
    
    # Set password if interactive
    if [[ "$INTERACTIVE" == "true" ]]; then
        log_info "Set password for $ADMIN_USERNAME:"
        if passwd "$ADMIN_USERNAME"; then
            log_success "Password set for $ADMIN_USERNAME"
        else
            log_error "Failed to set password for $ADMIN_USERNAME"
            return 1
        fi
    else
        # Generate random password and force change on first login
        local temp_password=$(openssl rand -base64 16)
        echo "$ADMIN_USERNAME:$temp_password" | chpasswd
        passwd -e "$ADMIN_USERNAME"
        log_warning "Temporary password set (will be forced to change on first login)"
        log_warning "Temporary password: $temp_password"
        echo "User: $ADMIN_USERNAME" >> "${BACKUP_DIR}/credentials.txt"
        echo "Temporary Password: $temp_password" >> "${BACKUP_DIR}/credentials.txt"
    fi
    
    log_success "Admin user configuration complete"
    return 0
}

setup_ssh_keys() {
    log_section "SSH Key Configuration"
    
    local target_user="${1:-$ADMIN_USERNAME}"
    
    if [[ -z "$target_user" ]]; then
        log_error "No target user specified for SSH key setup"
        return 1
    fi
    
    local user_home
    user_home=$(eval echo "~$target_user")
    local ssh_dir="$user_home/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    log_info "Setting up SSH keys for: $target_user"
    
    # Ask for key deployment method
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo ""
        echo "How would you like to provide the SSH public key?"
        echo "1) Paste the key now (recommended)"
        echo "2) Skip (use ssh-copy-id later)"
        echo "3) Import from current user"
        
        local choice
        read -r -p "Enter choice [1-3]: " choice
        
        case "$choice" in
            1)
                read -r -p "Paste your SSH public key: " ssh_pub_key
                if [[ -z "$ssh_pub_key" ]]; then
                    log_warning "No key provided, skipping SSH key setup"
                    return 0
                fi
                ;;
            2)
                log_info "SSH key setup skipped. Remember to run:"
                log_info "  ssh-copy-id -p $SSH_PORT $target_user@<server-ip>"
                return 0
                ;;
            3)
                if [[ -f "$HOME/.ssh/id_rsa.pub" ]] || [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
                    if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
                        ssh_pub_key=$(cat "$HOME/.ssh/id_ed25519.pub")
                    else
                        ssh_pub_key=$(cat "$HOME/.ssh/id_rsa.pub")
                    fi
                    log_info "Imported key from current user"
                else
                    log_error "No SSH keys found for current user"
                    return 1
                fi
                ;;
            *)
                log_warning "Invalid choice, skipping SSH key setup"
                return 0
                ;;
        esac
    else
        log_warning "Non-interactive mode: SSH key setup skipped"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create $ssh_dir"
        log_info "[DRY-RUN] Would add key to $auth_keys"
        return 0
    fi
    
    # Create .ssh directory
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Add key to authorized_keys
    if [[ -f "$auth_keys" ]] && grep -qF "$ssh_pub_key" "$auth_keys"; then
        log_info "SSH key already exists in $auth_keys"
    else
        echo "$ssh_pub_key" >> "$auth_keys"
        chmod 600 "$auth_keys"
        chown -R "$target_user:$target_user" "$ssh_dir"
        log_success "SSH public key added to $auth_keys"
    fi
    
    return 0
}

configure_password_policy() {
    log_section "Password Policy Configuration"
    
    if [[ "$CONFIGURE_PASSWORD_POLICY" != "true" ]]; then
        log_info "Password policy configuration disabled"
        return 0
    fi
    
    log_info "Configuring password policies"

    # Install libpam-pwquality
    install_package "libpam-pwquality"

    local pwquality_conf="/etc/security/pwquality.conf"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure password quality requirements"
        return 0
    fi

    # Only backup if file already exists
    [[ -f "$pwquality_conf" ]] && backup_file "$pwquality_conf"
    
    # Configure password quality
    cat > "$pwquality_conf" <<EOF
# Password quality requirements
minlen = $PASSWORD_MIN_LENGTH
minclass = $PASSWORD_MIN_COMPLEXITY
maxrepeat = 3
maxsequence = 3
gecoscheck = 1
dictcheck = 1
usercheck = 1
enforcing = 1
EOF
    
    log_success "Password quality configured"
    
    # Configure password aging
    local login_defs="/etc/login.defs"
    backup_file "$login_defs"
    
    sed -i "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   $PASSWORD_MAX_DAYS/" "$login_defs"
    sed -i "s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   $PASSWORD_MIN_DAYS/" "$login_defs"
    sed -i "s/^PASS_WARN_AGE.*/PASS_WARN_AGE   $PASSWORD_WARN_DAYS/" "$login_defs"
    
    log_success "Password aging policy configured"
    
    # Apply to existing users (optional)
    if prompt_yes_no "Apply password aging policy to existing users?" "n"; then
        for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
            chage -M "$PASSWORD_MAX_DAYS" -m "$PASSWORD_MIN_DAYS" -W "$PASSWORD_WARN_DAYS" "$user"
            log_info "Applied password policy to user: $user"
        done
        log_success "Password aging applied to existing users"
    fi
    
    return 0
}

configure_umask() {
    log_section "Default umask Configuration"
    
    if [[ "$CONFIGURE_UMASK" != "true" ]]; then
        log_info "Umask configuration disabled"
        return 0
    fi
    
    log_info "Setting default umask to $DEFAULT_UMASK"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would set umask to $DEFAULT_UMASK"
        return 0
    fi
    
    # Set in /etc/profile
    if ! grep -q "umask $DEFAULT_UMASK" /etc/profile; then
        echo "umask $DEFAULT_UMASK" >> /etc/profile
    fi
    
    # Set in /etc/bash.bashrc
    if ! grep -q "umask $DEFAULT_UMASK" /etc/bash.bashrc; then
        echo "umask $DEFAULT_UMASK" >> /etc/bash.bashrc
    fi
    
    # Set in /etc/login.defs
    sed -i "s/^UMASK.*/UMASK           $DEFAULT_UMASK/" /etc/login.defs
    
    log_success "Default umask configured"
    return 0
}
