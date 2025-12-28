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

# --- Validation Functions ---

is_root() {
    [[ $EUID -eq 0 ]]
}

check_root() {
    if ! is_root; then
        log_error "This script must be run as root or with sudo privileges"
        exit 1
    fi
}

is_debian_based() {
    [[ -f /etc/debian_version ]]
}

check_distribution() {
    if ! is_debian_based; then
        log_error "This script is designed for Debian/Ubuntu-based distributions"
        log_error "Detected: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        exit 1
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
    
    if [[ ! -f "$file" ]]; then
        log_warning "File $file does not exist, skipping backup"
        return 1
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
    
    if package_installed "$package"; then
        log_info "Package already installed: $package"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would install: $package"
        return 0
    fi
    
    log_info "Installing package: $package"
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
