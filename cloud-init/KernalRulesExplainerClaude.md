# Linux Kernel Hardening Rules Explained

I'll organize these by category and provide detailed explanations for each.

---

## IP Forwarding Controls

### `net.ipv4.ip_forward = 0`
### `net.ipv6.conf.all.forwarding = 0`

**What it does:** Disables the kernel's ability to forward packets between network interfaces. When set to 0, the system will not act as a router.

**How it protects:** Prevents the server from being used as a transit point to route traffic between networks. An attacker who compromises the server cannot use it to pivot into other network segments or bypass network segmentation.

**Why it's used:** Standard servers (web, database, application) have no legitimate need to forward packets. Only dedicated routers, VPN gateways, or NAT devices should have this enabled.

**Pros:**
- Prevents network pivoting attacks
- Enforces network segmentation
- Reduces attack surface

**Cons:**
- Must be enabled (set to 1) for Docker hosts, Kubernetes nodes, VPN servers, or any NAT/routing functionality
- Can break containerized workloads if disabled without consideration

---

## Source Routing Controls

### `net.ipv4.conf.all.accept_source_route = 0`
### `net.ipv4.conf.default.accept_source_route = 0`
### `net.ipv6.conf.all.accept_source_route = 0`
### `net.ipv6.conf.default.accept_source_route = 0`

**What it does:** Disables acceptance of source-routed packets. Source routing allows the sender to specify the exact path a packet should take through the network, overriding normal routing decisions.

**How it protects:** Blocks attackers from specifying custom routes that could:
- Bypass firewall rules by routing around security devices
- Redirect traffic through attacker-controlled hosts for interception
- Reach internal systems that shouldn't be directly accessible
- Perform man-in-the-middle attacks

**Why it's used:** Source routing is a legacy feature with almost no legitimate modern use cases. It's primarily exploited for malicious purposes.

**Pros:**
- Eliminates an entire class of routing-based attacks
- No impact on normal network operations
- Recommended by all major security benchmarks (CIS, STIG)

**Cons:**
- Extremely rare edge cases in specialized network diagnostics might need it
- Virtually no real-world downside to disabling

---

## ICMP Redirect Controls

### `net.ipv4.conf.all.accept_redirects = 0`
### `net.ipv4.conf.default.accept_redirects = 0`
### `net.ipv6.conf.all.accept_redirects = 0`
### `net.ipv6.conf.default.accept_redirects = 0`
### `net.ipv4.conf.all.secure_redirects = 0`
### `net.ipv4.conf.default.secure_redirects = 0`

**What it does:** Prevents the system from accepting ICMP redirect messages. These messages tell a host to update its routing table to use a different gateway for certain destinations. "Secure redirects" only accepts redirects from gateways in the default gateway list—but even this is disabled here.

**How it protects:** ICMP redirects can be spoofed by attackers to:
- Redirect traffic through malicious hosts (MITM attacks)
- Create denial-of-service by sending traffic to black holes
- Bypass network security controls
- Manipulate routing tables without authentication

**Why it's used:** Servers should have static, administrator-defined routes. Dynamic route changes via unauthenticated ICMP messages are a security risk.

**Pros:**
- Prevents routing table manipulation attacks
- Forces explicit route configuration
- No authentication mechanism for ICMP redirects makes them inherently insecure

**Cons:**
- In rare cases, legitimate network optimization via redirects won't work
- Administrators must manually configure optimal routes
- Slightly more administrative overhead in complex network topologies

---

### `net.ipv4.conf.all.send_redirects = 0`
### `net.ipv4.conf.default.send_redirects = 0`

**What it does:** Prevents the system from sending ICMP redirect messages to other hosts.

**How it protects:** Even if the server isn't a router, a compromised system could send malicious redirects to other hosts on the network, manipulating their routing tables.

**Why it's used:** Non-router systems have no business sending routing advice to other hosts.

**Pros:**
- Prevents compromised server from attacking other hosts via redirect injection
- Consistent with non-routing role

**Cons:**
- Must be enabled on legitimate routers
- None for standard servers

---

## Reverse Path Filtering

### `net.ipv4.conf.all.rp_filter = 1`
### `net.ipv4.conf.default.rp_filter = 1`

**What it does:** Enables strict reverse path filtering (also called "strict mode" or BCP38 filtering). When a packet arrives, the kernel checks if the source IP address is reachable via the interface it arrived on. If not, the packet is dropped.

**How it protects:**
- Blocks IP spoofing attacks where attackers forge source addresses
- Prevents packets with impossible source addresses from being processed
- Mitigates DDoS amplification attacks that rely on spoofed sources

**Why it's used:** A fundamental anti-spoofing protection. Legitimate traffic always comes from reachable sources via the expected interface.

**Pros:**
- Effective anti-spoofing protection
- Low overhead
- Industry best practice (RFC 3704)

**Cons:**
- Can cause issues with asymmetric routing (traffic arrives via different path than return traffic)
- May need to be set to 2 (loose mode) for multi-homed servers or complex routing
- VPN configurations sometimes require adjustment

---

## Martian Packet Logging

### `net.ipv4.conf.all.log_martians = 1`
### `net.ipv4.conf.default.log_martians = 1`

**What it does:** Enables logging of "martian" packets—packets with impossible or suspicious source addresses (e.g., private IPs arriving from public interfaces, loopback addresses from external sources, broadcast sources).

**How it protects:** Provides visibility into potential attacks or misconfigurations. Martian packets often indicate:
- IP spoofing attempts
- Network misconfiguration
- Reconnaissance activity
- Routing problems

**Why it's used:** Detection and forensics. You can't defend against what you can't see.

**Pros:**
- Valuable security telemetry
- Helps identify attacks and misconfigurations
- Useful for incident response

**Cons:**
- Can generate significant log volume in noisy environments
- Requires log monitoring infrastructure to be useful
- May need log rotation policies to manage disk usage

---

## SYN Flood Protection

### `net.ipv4.tcp_syncookies = 1`

**What it does:** Enables SYN cookies. During a SYN flood attack (where attackers send massive numbers of connection initiation requests), the server can become overwhelmed tracking half-open connections. SYN cookies encode connection state in the sequence number, allowing the server to avoid maintaining state until a valid ACK is received.

**How it protects:** Maintains service availability during SYN flood DDoS attacks by:
- Not allocating resources until the handshake completes
- Cryptographically validating that the client is legitimate
- Preventing resource exhaustion attacks

**Why it's used:** SYN floods remain one of the most common DDoS attack types.

**Pros:**
- Effective DDoS mitigation
- Automatically activates under attack conditions
- Minimal overhead during normal operation

**Cons:**
- Some TCP options (window scaling, SACK) are lost when cookies are used
- Slight performance impact under extreme attack conditions
- Not a complete DDoS solution—just one layer

---

### `net.ipv4.tcp_max_syn_backlog = 2048`

**What it does:** Sets the maximum number of half-open connections (connections in SYN_RECV state) that can be queued.

**How it protects:** Increases the threshold before SYN cookies must activate, allowing legitimate high-traffic scenarios to proceed normally while still having headroom.

**Why it's used:** Default value (often 128-512) is too low for busy servers.

**Pros:**
- Better handling of legitimate traffic bursts
- Delays SYN cookie activation to preserve TCP options
- Improves connection establishment under load

**Cons:**
- Higher memory usage per queued connection
- Too high a value could delay SYN cookie activation during real attacks
- Must be balanced with available system memory

---

### `net.ipv4.tcp_synack_retries = 2`

**What it does:** Limits the number of times the server will retransmit a SYN-ACK when it doesn't receive an ACK. Default is typically 5.

**How it protects:** Reduces the time resources are tied up waiting for potentially malicious half-open connections to complete. Fewer retries means faster timeout of abandoned connections.

**Why it's used:** Attackers send SYNs but never complete the handshake. Limiting retries frees resources faster.

**Pros:**
- Faster cleanup of dead connections
- Reduced resource consumption during attacks
- More responsive to legitimate connection failures

**Cons:**
- May cause issues with high-latency connections (satellite, intercontinental)
- Legitimate clients on lossy networks may fail to connect
- Consider higher values if serving global audience with poor connectivity

---

### `net.ipv4.tcp_syn_retries = 5`

**What it does:** Limits the number of times the system will retransmit a SYN when initiating an outbound connection.

**How it protects:** Prevents the server from wasting resources on unreachable destinations. Also limits how long malicious services could keep your server's resources tied up.

**Why it's used:** Provides reasonable timeout for outbound connections without excessive delays.

**Pros:**
- Prevents resource exhaustion on outbound connections
- Reasonable balance between reliability and responsiveness

**Cons:**
- Very high-latency targets might need more retries
- Generally well-balanced as-is

---

## ICMP Protections

### `net.ipv4.icmp_echo_ignore_broadcasts = 1`

**What it does:** Ignores ICMP echo requests (pings) sent to broadcast addresses.

**How it protects:** Prevents the server from participating in "Smurf" amplification attacks, where attackers send ping requests to broadcast addresses with a spoofed source, causing all hosts to flood the victim with replies.

**Why it's used:** No legitimate reason exists for responding to broadcast pings.

**Pros:**
- Prevents amplification attack participation
- Zero impact on legitimate operations

**Cons:**
- None meaningful

---

### `net.ipv4.icmp_ignore_bogus_error_responses = 1`

**What it does:** Ignores ICMP error messages that violate RFC 1122 (malformed or invalid error responses).

**How it protects:** Prevents processing of potentially malicious or malformed ICMP packets that could:
- Crash network stacks (historical vulnerabilities)
- Pollute logs with garbage
- Consume processing resources

**Why it's used:** Defense in depth against malformed packet attacks.

**Pros:**
- Reduces attack surface
- Cleaner logs
- No legitimate traffic affected

**Cons:**
- None

---

## Kernel Information Disclosure Protections

### `kernel.dmesg_restrict = 1`

**What it does:** Restricts access to kernel ring buffer (dmesg) to users with CAP_SYSLOG capability (typically root only).

**How it protects:** The kernel log contains potentially sensitive information:
- Memory addresses useful for exploit development
- Hardware details
- Boot parameters
- Driver errors that reveal system configuration

**Why it's used:** Unprivileged users and compromised low-privilege accounts shouldn't access kernel-level information.

**Pros:**
- Reduces information leakage
- Makes exploit development harder
- Defense in depth

**Cons:**
- Debugging as non-root user becomes harder
- Must use sudo or proper capabilities for troubleshooting

---

### `kernel.kptr_restrict = 1`

**What it does:** Hides kernel pointer addresses from non-privileged users. Addresses in /proc/kallsyms and similar interfaces are displayed as zeros.

**How it protects:** Kernel exploits often need to know the addresses of kernel functions or data structures. KASLR (Kernel Address Space Layout Randomization) is useless if attackers can simply read the addresses from /proc.

**Why it's used:** Essential companion to KASLR. Without this, address randomization provides minimal protection.

**Pros:**
- Dramatically increases exploit difficulty
- Critical for KASLR effectiveness
- Minimal operational impact

**Cons:**
- Debugging kernel issues requires root
- Some performance monitoring tools may need adjustment
- Value of 2 would hide even from root (more restrictive)

---

### `kernel.randomize_va_space = 2`

**What it does:** Enables full Address Space Layout Randomization (ASLR). Value meanings:
- 0 = Disabled
- 1 = Randomize stack, VDSO, shared memory
- 2 = Full randomization including heap (brk)

**How it protects:** Randomizes memory layout each time a program runs, making it extremely difficult for attackers to predict where code or data will be located. This breaks many exploit techniques that rely on known addresses.

**Why it's used:** Fundamental exploit mitigation. Without ASLR, return-oriented programming (ROP) and other attacks become trivial.

**Pros:**
- Major barrier to exploitation
- Negligible performance impact
- Industry standard

**Cons:**
- Very old/legacy applications might have compatibility issues
- Doesn't help if there's an information disclosure vulnerability
- Must be combined with PIE (Position Independent Executables) for full benefit

---

### `kernel.yama.ptrace_scope = 1`

**What it does:** Restricts which processes can use ptrace (process tracing/debugging). Value meanings:
- 0 = Classic: any process can trace any other process owned by same user
- 1 = Restricted: only parent can trace child, or processes with CAP_SYS_PTRACE
- 2 = Admin-only: only root can ptrace
- 3 = Disabled: no ptrace at all

**How it protects:** Prevents attackers from attaching debuggers to running processes to:
- Extract secrets from memory
- Inject malicious code
- Manipulate running applications
- Steal credentials from browsers, ssh-agents, etc.

**Why it's used:** Process debugging is a powerful capability that should be restricted.

**Pros:**
- Prevents credential theft from memory
- Blocks process injection attacks
- Legitimate debuggers (gdb) work when debugging own children

**Cons:**
- Some debugging scenarios require additional privileges
- Tools like strace may require root
- Development environments might need adjustments

---

## Kernel Panic Behavior

### `kernel.panic = 10`

**What it does:** After a kernel panic, the system will automatically reboot after 10 seconds. A value of 0 means "hang forever."

**How it protects:** Ensures the system recovers from crashes rather than remaining in an unknown, potentially vulnerable state.

**Why it's used:** Servers should recover from crashes automatically, especially in production where human intervention may be delayed.

**Pros:**
- Automatic recovery improves availability
- Prevents indefinite hang states
- Allows watchdog systems to restore service

**Cons:**
- Fast reboot might prevent crash dump analysis
- In some cases, you want to preserve state for forensics
- Should be coordinated with kdump if crash analysis is needed

---

### `kernel.panic_on_oops = 1`

**What it does:** Forces a kernel panic when an "oops" (non-fatal kernel error) occurs.

**How it protects:** Oops conditions often indicate:
- Memory corruption
- Potential exploitation
- Unstable system state

By panicking (and rebooting per the above setting), the system doesn't continue running in a potentially compromised state.

**Why it's used:** A system that has experienced kernel memory corruption cannot be trusted. Better to restart clean.

**Pros:**
- Prevents operation in corrupted state
- Limits exploitation window
- Forces clean recovery

**Cons:**
- Converts survivable errors into downtime
- May increase reboot frequency if there are driver bugs
- Should ensure panic=10 is also set for recovery

---

## Core Dump Security

### `fs.suid_dumpable = 0`

**What it does:** Prevents core dumps for setuid/setgid programs. Values:
- 0 = No dumps for SUID programs
- 1 = Standard core dumps
- 2 = Dumps with restricted permissions

**How it protects:** SUID programs run with elevated privileges and may handle sensitive data. Core dumps could expose:
- Passwords or keys from memory
- Information useful for exploitation
- Privileged data structures

**Why it's used:** Core dumps are a classic source of information disclosure.

**Pros:**
- Prevents sensitive data exposure
- Security best practice
- Minimal operational impact

**Cons:**
- Debugging SUID program crashes requires configuration changes
- May need temporary adjustment during development

---

## Network Performance Tuning

### `net.core.rmem_max = 134217728` (128 MB)
### `net.core.wmem_max = 134217728` (128 MB)
### `net.core.rmem_default = 67108864` (64 MB)
### `net.core.wmem_default = 67108864` (64 MB)

**What it does:** Sets maximum and default socket buffer sizes for receiving (rmem) and sending (wmem) data.

**How it protects:** Not primarily security settings—these are performance tuning. However, adequate buffers:
- Prevent packet drops under load
- Maintain service availability during traffic spikes
- Enable high-throughput applications

**Why it's used:** Default kernel values are too conservative for modern high-speed networks and server workloads.

**Pros:**
- Dramatically improves throughput for high-bandwidth applications
- Reduces packet loss
- Essential for 10Gbps+ networks

**Cons:**
- Higher memory consumption
- Oversized buffers can increase latency (bufferbloat)
- Should be tuned to actual workload

---

### `net.core.netdev_max_backlog = 5000`

**What it does:** Sets the maximum number of packets queued on the input side when the interface receives packets faster than the kernel can process them.

**How it protects:** Prevents packet drops during traffic bursts, maintaining availability.

**Why it's used:** Default (usually 1000) is insufficient for high-traffic servers.

**Pros:**
- Handles traffic bursts gracefully
- Reduces drops under load
- Improves application responsiveness

**Cons:**
- Higher memory usage
- Excessive queuing can increase latency

---

### `net.core.somaxconn = 4096`

**What it does:** Sets the maximum number of connections queued for acceptance by listening sockets (the listen() backlog).

**How it protects:** Ensures legitimate connections aren't refused during traffic spikes or slow application processing.

**Why it's used:** Default (often 128) is woefully inadequate for busy web servers or any connection-heavy service.

**Pros:**
- Handles connection bursts
- Prevents "connection refused" errors under load
- Essential for high-traffic applications

**Cons:**
- Memory usage per queued connection
- Applications must also set their listen backlog appropriately

---

## IPv6 Configuration

### `net.ipv6.conf.all.disable_ipv6 = 0`
### `net.ipv6.conf.default.disable_ipv6 = 0`
### `net.ipv6.conf.lo.disable_ipv6 = 0`

**What it does:** Keeps IPv6 enabled. Setting to 1 would disable it.

**How it protects:** These are set to 0 (enabled), which is about functionality, not hardening. Some argue disabling unused IPv6 reduces attack surface, but many modern services require it.

**Why it's used:** IPv6 is increasingly necessary. Disabling it can break:
- Docker/container networking
- systemd-resolved
- Various cloud provider features
- Modern application frameworks

**Pros:**
- Full network protocol support
- Avoids breaking dependencies
- Future-ready

**Cons:**
- If truly not using IPv6, disabling it would marginally reduce attack surface
- Requires proper IPv6 firewall rules if exposed

---

### `net.ipv6.conf.all.accept_ra = 0`
### `net.ipv6.conf.default.accept_ra = 0`

**What it does:** Disables acceptance of Router Advertisements. RAs are how IPv6 routers announce their presence and provide configuration (addresses, routes, DNS).

**How it protects:** Prevents rogue RA attacks where an attacker on the local network advertises themselves as a router to:
- Perform man-in-the-middle attacks
- Redirect traffic
- Provide malicious DNS servers
- Hijack default routes

**Why it's used:** Servers should have static IPv6 configuration, not accept dynamic configuration from the network.

**Pros:**
- Prevents rogue router attacks
- Ensures predictable network configuration
- Defense against network-level MITM

**Cons:**
- Requires manual/static IPv6 configuration
- Cannot use SLAAC (Stateless Address Autoconfiguration)
- May need adjustment in some cloud environments that rely on RAs

---

## Filesystem Protections

### `fs.protected_hardlinks = 1`
### `fs.protected_symlinks = 1`

**What it does:** Restricts hardlink and symlink creation in world-writable directories (like /tmp). Users can only create links to files they own or have write access to.

**How it protects:** Prevents classic race condition attacks where an attacker:
1. Creates a symlink in /tmp pointing to a sensitive file (e.g., /etc/passwd)
2. Waits for a privileged program to write to the expected /tmp file
3. The privileged program follows the symlink and overwrites the sensitive file

These attacks (TOCTOU - time-of-check-time-of-use) have been used for decades for privilege escalation.

**Why it's used:** Eliminates entire classes of local privilege escalation vulnerabilities.

**Pros:**
- Blocks symlink/hardlink attacks
- Protects against many historical vulnerabilities
- Minimal impact on legitimate operations

**Cons:**
- Rare edge cases where programs legitimately need to link to files they don't own
- Virtually no downside in practice

---

### `fs.protected_fifos = 2`
### `fs.protected_regular = 2`

**What it does:** Similar protection for FIFOs (named pipes) and regular files. Value meanings:
- 0 = Disabled
- 1 = Protected in world-writable sticky directories
- 2 = Protected in all group-writable directories

**How it protects:** Extends the hardlink/symlink protections to other file types that could be exploited similarly. Prevents unauthorized file replacement attacks in shared directories.

**Why it's used:** Defense in depth. Same TOCTOU attack principles apply to FIFOs and regular files.

**Pros:**
- Comprehensive protection against file-based race conditions
- Value of 2 provides broader protection

**Cons:**
- Slightly more restrictive than value 1
- Extremely rare compatibility issues with legacy applications

---

## Summary Table

| Category | Settings | Primary Benefit |
|----------|----------|-----------------|
| IP Forwarding | ip_forward, forwarding | Prevents network pivoting |
| Source Routing | accept_source_route | Blocks routing manipulation |
| ICMP Redirects | accept_redirects, send_redirects, secure_redirects | Prevents routing attacks |
| Reverse Path | rp_filter | Blocks IP spoofing |
| Martian Logging | log_martians | Attack detection |
| SYN Flood | tcp_syncookies, tcp_max_syn_backlog, tcp_syn*_retries | DDoS mitigation |
| ICMP Hardening | icmp_echo_ignore_broadcasts, icmp_ignore_bogus | Blocks amplification attacks |
| Kernel Info | dmesg_restrict, kptr_restrict, randomize_va_space | Exploit mitigation |
| Process Security | yama.ptrace_scope | Prevents process injection |
| Panic Behavior | panic, panic_on_oops | Secure failure mode |
| Core Dumps | suid_dumpable | Prevents info disclosure |
| Network Performance | rmem_*, wmem_*, somaxconn, netdev_max_backlog | Availability |
| IPv6 Hardening | accept_ra | Prevents rogue router attacks |
| Filesystem | protected_* | Blocks privilege escalation |

This is a solid baseline configuration. For your specific multi-cloud server fleet, you'll want to verify that `ip_forward` settings are appropriate for any Docker/container hosts, and ensure the performance tuning values match your actual workload requirements.