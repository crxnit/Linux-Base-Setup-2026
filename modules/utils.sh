#!/bin/bash
# ============================================================================
# Utility Functions Module
# ============================================================================
# Common utility functions used across all modules
# ============================================================================

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# --- Logging Functions ---

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE" >&2
}

log_section() {
    local message="$1"
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BOLD}========================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}$message${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}========================================${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

log_step() {
    local step="$1"
    local message="$2"
    echo -e "${BLUE}[$step]${NC} $message" | tee -a "$LOG_FILE"
}

# --- Progress Indicator ---

show_progress() {
    local message="$1"
    local pid=$2
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c] %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

# --- Essential Tools Installation ---

install_essential_tools() {
    echo "Checking for essential tools..."

    local tools_to_install=()
    local tools_installed=false

    # Check for sudo
    if ! command -v sudo &> /dev/null; then
        echo "[NOTICE] sudo not found - will install"
        tools_to_install+=("sudo")
    fi

    # Check for curl
    if ! command -v curl &> /dev/null; then
        echo "[NOTICE] curl not found - will install"
        tools_to_install+=("curl")
    fi

    # Check for vim (or install nano as alternative)
    if ! command -v vim &> /dev/null && ! command -v nano &> /dev/null; then
        echo "[NOTICE] No text editor found - will install vim"
        tools_to_install+=("vim")
    fi

    # Install missing tools
    if [ ${#tools_to_install[@]} -gt 0 ]; then
        # In dry-run mode, just report what would be installed
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY-RUN] Would install essential tools: ${tools_to_install[*]}"
            return 0
        fi

        echo "Installing essential tools: ${tools_to_install[*]}"

        # Update package lists first
        apt-get update -qq || {
            echo "ERROR: Failed to update package lists"
            exit 1
        }

        # Install each tool
        for tool in "${tools_to_install[@]}"; do
            echo "Installing $tool..."
            if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$tool"; then
                echo "✓ Installed: $tool"
                tools_installed=true
            else
                echo "ERROR: Failed to install $tool"
                exit 1
            fi
        done

        # Configure sudo if it was just installed
        if [[ " ${tools_to_install[*]} " =~ " sudo " ]]; then
            echo "Configuring sudo..."
            # Ensure sudo group exists
            if ! getent group sudo > /dev/null 2>&1; then
                groupadd sudo
            fi
            # Configure sudoers file
            if [ -f /etc/sudoers ]; then
                # Ensure sudo group has permissions
                if ! grep -q "^%sudo" /etc/sudoers; then
                    echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers
                fi
            fi
            echo "✓ sudo configured"
        fi

        echo "✓ All essential tools installed"
    else
        echo "✓ All essential tools already installed"
    fi

    return 0
}

# --- Validation Functions ---

is_root() {
    [[ $EUID -eq 0 ]]
}

check_root() {
    if ! is_root; then
        echo -e "${RED}[ERROR]${NC} This script must be run as root or with sudo privileges"
        exit 1
    fi
}

is_debian_based() {
    [[ -f /etc/debian_version ]]
}

get_distribution() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

get_distribution_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

get_distribution_codename() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_CODENAME"
    else
        echo "unknown"
    fi
}

is_ubuntu() {
    [[ "$(get_distribution)" == "ubuntu" ]]
}

is_debian() {
    [[ "$(get_distribution)" == "debian" ]]
}

get_architecture() {
    uname -m
}

is_arm() {
    local arch
    arch=$(get_architecture)
    [[ "$arch" =~ ^(arm|aarch64)$ ]]
}

is_amd64() {
    local arch
    arch=$(get_architecture)
    [[ "$arch" == "x86_64" ]]
}

is_arm64() {
    [[ "$(get_architecture)" == "aarch64" ]]
}

is_arm32() {
    local arch
    arch=$(get_architecture)
    [[ "$arch" =~ ^armv[67]l$ ]]
}

check_distribution() {
    if ! is_debian_based; then
        log_error "This script is designed for Debian/Ubuntu-based distributions"
        log_error "Detected: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        exit 1
    fi
    
    local distro
    local version
    local arch
    
    distro=$(get_distribution)
    version=$(get_distribution_version)
    arch=$(get_architecture)
    
    log_info "Distribution: $(echo "$distro" | tr '[:lower:]' '[:upper:]') $version"
    log_info "Architecture: $arch"
    
    # Check for supported versions
    if is_ubuntu; then
        case "$version" in
            20.04|22.04|24.04)
                log_success "Ubuntu $version is supported"
                ;;
            *)
                log_warning "Ubuntu $version may not be fully tested"
                log_warning "Recommended versions: 20.04 LTS, 22.04 LTS, 24.04 LTS"
                if [[ "$INTERACTIVE" == "true" ]]; then
                    if ! prompt_yes_no "Continue anyway?" "y"; then
                        exit 1
                    fi
                fi
                ;;
        esac
    elif is_debian; then
        case "$version" in
            11|12)
                log_success "Debian $version is supported"
                ;;
            *)
                log_warning "Debian $version may not be fully tested"
                log_warning "Recommended versions: 11 (Bullseye), 12 (Bookworm)"
                if [[ "$INTERACTIVE" == "true" ]]; then
                    if ! prompt_yes_no "Continue anyway?" "y"; then
                        exit 1
                    fi
                fi
                ;;
        esac
    fi
    
    # Architecture-specific warnings
    if is_arm32; then
        log_warning "32-bit ARM detected - some features may have limited support"
    fi
}

validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        return 1
    fi
    return 0
}

validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# --- Backup Functions ---

backup_file() {
    local file="$1"
    local backup_path="${BACKUP_DIR}/$(basename "$file").$(date +%Y%m%d_%H%M%S)"

    # File not existing is not an error - just skip backup
    if [[ ! -f "$file" ]]; then
        log_info "File $file does not exist, skipping backup"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would backup: $file -> $backup_path"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    if cp -a "$file" "$backup_path"; then
        log_success "Backed up: $file -> $backup_path"
        return 0
    else
        log_error "Failed to backup: $file"
        return 1
    fi
}

# --- User Interaction Functions ---

prompt_yes_no() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$INTERACTIVE" != "true" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi
    
    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi
    
    while true; do
        read -r -p "$prompt" response
        response=${response:-$default}
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

prompt_input() {
    local message="$1"
    local default="$2"
    local validator="${3:-}"
    
    if [[ "$INTERACTIVE" != "true" ]]; then
        echo "$default"
        return 0
    fi
    
    local prompt
    if [[ -n "$default" ]]; then
        prompt="$message [$default]: "
    else
        prompt="$message: "
    fi
    
    while true; do
        read -r -p "$prompt" response
        response=${response:-$default}
        
        if [[ -z "$response" && -z "$default" ]]; then
            echo "This field is required."
            continue
        fi
        
        if [[ -n "$validator" ]]; then
            if $validator "$response"; then
                echo "$response"
                return 0
            else
                echo "Invalid input. Please try again."
                continue
            fi
        fi
        
        echo "$response"
        return 0
    done
}

prompt_password() {
    local message="$1"
    local min_length="${2:-8}"
    
    while true; do
        read -r -s -p "$message: " password1
        echo
        read -r -s -p "Confirm password: " password2
        echo
        
        if [[ "$password1" != "$password2" ]]; then
            log_error "Passwords do not match. Please try again."
            continue
        fi
        
        if [[ ${#password1} -lt $min_length ]]; then
            log_error "Password must be at least $min_length characters long."
            continue
        fi
        
        echo "$password1"
        return 0
    done
}

# --- System Information Functions ---

get_system_info() {
    local cpu_cores
    local ram_gb
    local disk_size
    local ip_address
    local os_version
    
    cpu_cores=$(nproc)
    ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    disk_size=$(df -h / | awk 'NR==2 {print $2}')
    ip_address=$(hostname -I | awk '{print $1}')
    os_version=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    
    echo "CPU Cores: $cpu_cores"
    echo "RAM: ${ram_gb}GB"
    echo "Disk: $disk_size"
    echo "IP: $ip_address"
    echo "OS: $os_version"
}

generate_hostname() {
    local prefix="$1"
    local cpu_cores ram_gb disk_size ip_address ip_segment
    
    cpu_cores=$(nproc)
    ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    disk_size=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//;s/T/*1000/')
    ip_address=$(hostname -I | awk '{print $1}')
    ip_segment=$(echo "$ip_address" | awk -F'.' '{print $3"-"$4}')
    
    echo "${prefix}-${ip_segment}-${cpu_cores}c${ram_gb}g"
}

# --- Package Management Functions ---

package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

install_package() {
    local package="$1"
    local distro_specific="${2:-}"
    
    # Handle distribution-specific package names
    if [[ -n "$distro_specific" ]]; then
        if is_ubuntu && [[ "$distro_specific" == "ubuntu:"* ]]; then
            package="${distro_specific#ubuntu:}"
        elif is_debian && [[ "$distro_specific" == "debian:"* ]]; then
            package="${distro_specific#debian:}"
        fi
    fi
    
    if package_installed "$package"; then
        log_info "Package already installed: $package"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would install: $package"
        return 0
    fi
    
    log_info "Installing package: $package"
    
    # Update package lists if they're stale (older than 1 day)
    local apt_list="/var/lib/apt/lists"
    if [[ ! -d "$apt_list" ]] || [[ $(find "$apt_list" -type f -mtime -1 | wc -l) -eq 0 ]]; then
        log_info "Updating package lists..."
        apt-get update -qq >> "$LOG_FILE" 2>&1 || log_warning "Failed to update package lists"
    fi
    
    if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package" >> "$LOG_FILE" 2>&1; then
        log_success "Installed: $package"
        return 0
    else
        log_error "Failed to install: $package"
        return 1
    fi
}

# --- Service Management Functions ---

service_exists() {
    systemctl list-unit-files | grep -q "^$1.service"
}

service_active() {
    systemctl is-active --quiet "$1"
}

enable_service() {
    local service="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would enable service: $service"
        return 0
    fi
    
    if systemctl enable "$service" >> "$LOG_FILE" 2>&1; then
        log_success "Enabled service: $service"
        return 0
    else
        log_error "Failed to enable service: $service"
        return 1
    fi
}

start_service() {
    local service="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would start service: $service"
        return 0
    fi
    
    if systemctl start "$service" >> "$LOG_FILE" 2>&1; then
        log_success "Started service: $service"
        return 0
    else
        log_error "Failed to start service: $service"
        return 1
    fi
}

restart_service() {
    local service="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would restart service: $service"
        return 0
    fi
    
    if systemctl restart "$service" >> "$LOG_FILE" 2>&1; then
        log_success "Restarted service: $service"
        return 0
    else
        log_error "Failed to restart service: $service"
        return 1
    fi
}

# --- Cleanup Functions ---

cleanup_on_error() {
    log_error "Script encountered an error. Check log file: $LOG_FILE"
    log_info "Backup directory: $BACKUP_DIR"
    exit 1
}

# --- File Modification Functions ---

ensure_line_in_file() {
    local line="$1"
    local file="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would ensure line in $file: $line"
        return 0
    fi
    
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
        log_info "Added line to $file"
    fi
}

replace_or_add_line() {
    local pattern="$1"
    local replacement="$2"
    local file="$3"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would modify $file: $pattern -> $replacement"
        return 0
    fi
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        sed -i "s|$pattern|$replacement|g" "$file"
    else
        echo "$replacement" >> "$file"
    fi
}
