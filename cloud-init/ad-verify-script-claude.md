# -----------------------------------------------------------------------------
  # ADDITIONAL HARDENING VERIFICATION
  # -----------------------------------------------------------------------------
  
  - path: /usr/local/bin/verify-additional-hardening.sh
    owner: root:root
    permissions: '0755'
    content: |
      #!/bin/bash
      # Verify additional hardening settings
      
      set -euo pipefail
      
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
      
      check_service_active() {
          local service="$1"
          if systemctl is-active --quiet "$service" 2>/dev/null; then
              echo -e "${GREEN}[PASS]${NC} Service $service is active"
              ((PASS++))
          else
              echo -e "${RED}[FAIL]${NC} Service $service is not active"
              ((FAIL++))
          fi
      }
      
      check_service_disabled() {
          local service="$1"
          if ! systemctl is-enabled --quiet "$service" 2>/dev/null; then
              echo -e "${GREEN}[PASS]${NC} Service $service is disabled"
              ((PASS++))
          else
              echo -e "${YELLOW}[WARN]${NC} Service $service is enabled"
              ((WARN++))
          fi
      }
      
      check_file_exists() {
          local file="$1"
          if [[ -f "$file" ]]; then
              echo -e "${GREEN}[PASS]${NC} File exists: $file"
              ((PASS++))
          else
              echo -e "${RED}[FAIL]${NC} File missing: $file"
              ((FAIL++))
          fi
      }
      
      check_permission() {
          local file="$1"
          local expected="$2"
          if [[ -e "$file" ]]; then
              local actual=$(stat -c "%a" "$file")
              if [[ "$actual" == "$expected" ]]; then
                  echo -e "${GREEN}[PASS]${NC} $file has correct permissions ($actual)"
                  ((PASS++))
              else
                  echo -e "${YELLOW}[WARN]${NC} $file has permissions $actual (expected: $expected)"
                  ((WARN++))
              fi
          fi
      }
      
      # Main
      print_header "ADDITIONAL HARDENING VERIFICATION"
      echo "Timestamp: $(date)"
      
      print_section "SSH HARDENING"
      check_file_exists "/etc/ssh/sshd_config.d/99-hardening.conf"
      check_file_exists "/etc/ssh/banner"
      
      # Check SSH settings
      if sshd -T 2>/dev/null | grep -q "permitrootlogin no"; then
          echo -e "${GREEN}[PASS]${NC} Root login is disabled"
          ((PASS++))
      else
          echo -e "${RED}[FAIL]${NC} Root login may be enabled"
          ((FAIL++))
      fi
      
      if sshd -T 2>/dev/null | grep -q "passwordauthentication no"; then
          echo -e "${GREEN}[PASS]${NC} Password authentication is disabled"
          ((PASS++))
      else
          echo -e "${YELLOW}[WARN]${NC} Password authentication may be enabled"
          ((WARN++))
      fi
      
      print_section "SECURITY SERVICES"
      check_service_active "fail2ban"
      check_service_active "auditd"
      check_service_active "chrony"
      
      print_section "DISABLED SERVICES"
      for svc in avahi-daemon cups bluetooth ModemManager; do
          check_service_disabled "$svc"
      done
      
      print_section "AUTOMATIC UPDATES"
      check_file_exists "/etc/apt/apt.conf.d/50unattended-upgrades"
      check_file_exists "/etc/apt/apt.conf.d/20auto-upgrades"
      
      print_section "AUDIT CONFIGURATION"
      check_file_exists "/etc/audit/rules.d/99-hardening.rules"
      if auditctl -l 2>/dev/null | grep -q "time-change"; then
          echo -e "${GREEN}[PASS]${NC} Audit rules are loaded"
          ((PASS++))
      else
          echo -e "${YELLOW}[WARN]${NC} Some audit rules may not be loaded"
          ((WARN++))
      fi
      
      print_section "FILESYSTEM HARDENING"
      if mount | grep "/tmp" | grep -q "nosuid"; then
          echo -e "${GREEN}[PASS]${NC} /tmp has nosuid"
          ((PASS++))
      else
          echo -e "${YELLOW}[WARN]${NC} /tmp may not have nosuid"
          ((WARN++))
      fi
      
      if mount | grep "/dev/shm" | grep -q "noexec"; then
          echo -e "${GREEN}[PASS]${NC} /dev/shm has noexec"
          ((PASS++))
      else
          echo -e "${YELLOW}[WARN]${NC} /dev/shm may not have noexec"
          ((WARN++))
      fi
      
      print_section "LOGGING"
      if [[ -d /var/log/journal ]]; then
          echo -e "${GREEN}[PASS]${NC} Persistent journald logging enabled"
          ((PASS++))
      else
          echo -e "${YELLOW}[WARN]${NC} Journald may not be persistent"
          ((WARN++))
      fi
      
      print_section "CRON RESTRICTIONS"
      if [[ -f /etc/cron.allow ]]; then
          echo -e "${GREEN}[PASS]${NC} /etc/cron.allow exists"
          ((PASS++))
          check_permission "/etc/cron.allow" "600"
      else
          echo -e "${YELLOW}[WARN]${NC} /etc/cron.allow not configured"
          ((WARN++))
      fi
      
      print_section "FAIL2BAN STATUS"
      if command -v fail2ban-client &>/dev/null; then
          jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*://' | tr -d ' ')
          echo "  Active jails: $jails"
          
          for jail in $(echo "$jails" | tr ',' ' '); do
              banned=$(fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
              echo "    $jail: $banned currently banned"
          done
      fi
      
      # Summary
      print_header "SUMMARY"
      echo ""
      echo -e "  ${GREEN}PASSED:${NC}   $PASS"
      echo -e "  ${RED}FAILED:${NC}   $FAIL"
      echo -e "  ${YELLOW}WARNINGS:${NC} $WARN"
      echo ""
      
      if [[ $FAIL -eq 0 ]]; then
          echo -e "${GREEN}✓ All critical checks passed!${NC}"
          exit 0
      else
          echo -e "${RED}✗ Some checks failed${NC}"
          exit 1
      fi