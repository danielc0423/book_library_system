#!/bin/bash
# ====================================
# Bastion Host User Data Script
# Oracle Cloud Infrastructure (OCI)
# Book Library System
# ====================================

set -e  # Exit on any error

# Variables passed from Terraform
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/bastion-setup.log
}

log "Starting bastion host setup for ${PROJECT_NAME} ${ENVIRONMENT} environment"

# Update system packages
log "Updating system packages..."
yum update -y

# Install essential packages for bastion host
log "Installing essential packages..."
yum install -y \
    openssh-clients \
    openssh-server \
    fail2ban \
    htop \
    vim \
    wget \
    curl \
    git \
    screen \
    tmux \
    rsync \
    unzip \
    which \
    bind-utils \
    telnet \
    nc \
    tcpdump \
    strace \
    lsof \
    iotop \
    iftop \
    nmap \
    traceroute \
    mtr \
    audit \
    aide \
    chrony

# Configure SSH for enhanced security
log "Configuring SSH security..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

cat > /etc/ssh/sshd_config << 'EOF'
# SSH Configuration for Bastion Host
Port 22
Protocol 2

# Logging
SyslogFacility AUTHPRIV
LogLevel INFO

# Authentication
LoginGraceTime 60
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 10
MaxStartups 10:30:60

# Public key authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password authentication (disabled for security)
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Kerberos and GSSAPI (disabled)
KerberosAuthentication no
GSSAPIAuthentication no

# X11 and other forwarding
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 3

# Environment
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS

# Subsystem
Subsystem sftp /usr/libexec/openssh/sftp-server

# Allow specific users only
AllowUsers opc

# Restrict to specific IP ranges (will be configured via security groups)
# AllowUsers opc@10.0.0.0/16

# Banner
Banner /etc/ssh/banner
EOF

# Create SSH banner
log "Creating SSH banner..."
cat > /etc/ssh/banner << 'EOF'
***************************************************************************
                        AUTHORIZED ACCESS ONLY
                        
This system is for authorized users only. Individual use of this system
and all activities performed on this system are monitored and recorded.

Anyone using this system expressly consents to such monitoring and recording.
Be aware that if unauthorized activity is detected, system personnel may
provide the evidence of such monitoring and recording to law enforcement
officials.

All activities are logged and monitored.
***************************************************************************
EOF

# Configure fail2ban for brute force protection
log "Configuring fail2ban..."
systemctl enable fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd
destemail = admin@company.com
sender = fail2ban@bastion
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 3600
findtime = 600

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 6
bantime = 3600
findtime = 600
EOF

# Configure firewall
log "Configuring firewall..."
systemctl enable firewalld
systemctl start firewalld

# Allow SSH
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --remove-service=dhcpv6-client
firewall-cmd --reload

# Configure audit logging
log "Configuring audit logging..."
systemctl enable auditd

cat >> /etc/audit/rules.d/audit.rules << 'EOF'
# Bastion host audit rules

# Record all login attempts
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins
-w /var/run/utmp -p wa -k session

# Record all authentication events
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k passwd_changes
-w /etc/sudoers -p wa -k sudoers_changes

# Record all SSH activities
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/ssh/ -p wa -k ssh_config

# Record privileged commands
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands
-a always,exit -F arch=b32 -S execve -F euid=0 -k root_commands

# Record file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -k delete

# Record network connections
-a always,exit -F arch=b64 -S socket -F a0=10 -k network_connect_ipv4
-a always,exit -F arch=b64 -S socket -F a0=2 -k network_connect_ipv4
EOF

# Restart auditd
service auditd restart

# Configure system monitoring
log "Configuring system monitoring..."

# Create monitoring script
cat > /usr/local/bin/bastion-monitor.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/bastion-monitor.log"
PROJECT_NAME="$1"
ENVIRONMENT="$2"

log_metric() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check system metrics
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | tr -d ' ')

# Check active SSH connections
SSH_CONNECTIONS=$(who | wc -l)
ACTIVE_USERS=$(who | awk '{print $1}' | sort | uniq | wc -l)

# Check failed login attempts in last hour
FAILED_LOGINS=$(journalctl --since "1 hour ago" | grep "Failed password" | wc -l)

# Log metrics
log_metric "METRICS: CPU=${CPU_USAGE}% MEM=${MEMORY_USAGE}% DISK=${DISK_USAGE}% LOAD=${LOAD_AVG} SSH_CONN=${SSH_CONNECTIONS} USERS=${ACTIVE_USERS} FAILED_LOGIN=${FAILED_LOGINS}"

# Check for security alerts
if [[ $FAILED_LOGINS -gt 10 ]]; then
    log_metric "ALERT: High number of failed login attempts: $FAILED_LOGINS"
fi

if [[ $(echo "$CPU_USAGE > 80" | bc -l) -eq 1 ]]; then
    log_metric "ALERT: High CPU usage: $CPU_USAGE%"
fi

if [[ $(echo "$MEMORY_USAGE > 80" | bc -l) -eq 1 ]]; then
    log_metric "ALERT: High memory usage: $MEMORY_USAGE%"
fi

if [[ $DISK_USAGE -gt 80 ]]; then
    log_metric "ALERT: High disk usage: $DISK_USAGE%"
fi
EOF

chmod +x /usr/local/bin/bastion-monitor.sh

# Create monitoring service
cat > /etc/systemd/system/bastion-monitor.service << EOF
[Unit]
Description=Bastion Host Monitoring
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bastion-monitor.sh ${PROJECT_NAME} ${ENVIRONMENT}
User=root
StandardOutput=journal
StandardError=journal
EOF

# Create monitoring timer
cat > /etc/systemd/system/bastion-monitor.timer << 'EOF'
[Unit]
Description=Bastion Host Monitoring Timer
Requires=bastion-monitor.service

[Timer]
OnCalendar=*:*:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable monitoring
systemctl daemon-reload
systemctl enable bastion-monitor.timer
systemctl start bastion-monitor.timer

# Configure log rotation for bastion logs
log "Configuring log rotation..."
cat > /etc/logrotate.d/bastion << 'EOF'
/var/log/bastion-*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 root root
}
EOF

# Install and configure Oracle client tools
log "Installing Oracle client tools..."
yum install -y oracle-instantclient19.3-basic oracle-instantclient19.3-sqlplus oracle-instantclient19.3-tools

# Configure Oracle environment
echo "export ORACLE_HOME=/usr/lib/oracle/19.3/client64" >> /etc/profile
echo "export LD_LIBRARY_PATH=/usr/lib/oracle/19.3/client64/lib" >> /etc/profile
echo "export PATH=/usr/lib/oracle/19.3/client64/bin:\$PATH" >> /etc/profile

# Create utilities for system administrators
log "Creating utility scripts..."

# Create connection test script
cat > /usr/local/bin/test-connections.sh << 'EOF'
#!/bin/bash

echo "Testing connectivity from bastion host..."

# Test database connectivity (assuming it's in the database subnet)
echo "Testing database connectivity..."
nc -z 10.0.3.4 1521 && echo "Database: OK" || echo "Database: FAILED"

# Test application servers (in private subnet)
echo "Testing application server connectivity..."
for i in {1..5}; do
    nc -z 10.0.2.$((10+i)) 8000 && echo "App Server $i: OK" || echo "App Server $i: FAILED"
done

# Test load balancer
echo "Testing load balancer connectivity..."
nc -z 10.0.1.10 80 && echo "Load Balancer HTTP: OK" || echo "Load Balancer HTTP: FAILED"
nc -z 10.0.1.10 443 && echo "Load Balancer HTTPS: OK" || echo "Load Balancer HTTPS: FAILED"

echo "Connection tests completed."
EOF

chmod +x /usr/local/bin/test-connections.sh

# Create emergency shutdown script
cat > /usr/local/bin/emergency-shutdown.sh << 'EOF'
#!/bin/bash

echo "EMERGENCY SHUTDOWN INITIATED"
logger "EMERGENCY: Bastion host emergency shutdown initiated by $(whoami) from $(who am i | awk '{print $NF}')"

# Stop all non-essential services
systemctl stop httpd nginx apache2 2>/dev/null || true

# Kill all user sessions except current
who | grep -v "$(who am i | awk '{print $1}')" | awk '{print $1}' | xargs -I {} pkill -u {} 2>/dev/null || true

echo "Emergency procedures completed. Manual intervention required."
EOF

chmod +x /usr/local/bin/emergency-shutdown.sh

# Create session logging script
cat > /usr/local/bin/log-session.sh << 'EOF'
#!/bin/bash

SESSION_LOG_DIR="/var/log/sessions"
mkdir -p "$SESSION_LOG_DIR"

SESSION_ID="${USER}_$(date +%Y%m%d_%H%M%S)_$$"
SESSION_LOG="$SESSION_LOG_DIR/session_$SESSION_ID.log"

echo "Session started: $(date)" >> "$SESSION_LOG"
echo "User: $USER" >> "$SESSION_LOG"
echo "TTY: $(tty)" >> "$SESSION_LOG"
echo "From: $SSH_CLIENT" >> "$SESSION_LOG"
echo "Command: $SSH_ORIGINAL_COMMAND" >> "$SESSION_LOG"
echo "----------------------------------------" >> "$SESSION_LOG"

# Log the session
script -f -q "$SESSION_LOG"

echo "Session ended: $(date)" >> "$SESSION_LOG"
EOF

chmod +x /usr/local/bin/log-session.sh

# Configure MOTD (Message of the Day)
log "Configuring MOTD..."
cat > /etc/motd << EOF
================================================================================
                        ${PROJECT_NAME^^} BASTION HOST
                        Environment: ${ENVIRONMENT^^}
================================================================================

Welcome to the ${PROJECT_NAME} bastion host for the ${ENVIRONMENT} environment.

This system is monitored and all activities are logged.

Available utilities:
  - test-connections.sh    : Test connectivity to backend systems
  - bastion-monitor.sh     : Manual system monitoring
  - emergency-shutdown.sh  : Emergency procedures (admin only)

System Information:
  - Hostname: $(hostname)
  - IP Address: $(hostname -I | awk '{print $1}')
  - OS: $(cat /etc/oracle-release)
  - Kernel: $(uname -r)
  - Uptime: $(uptime -p)

Security Notes:
  - All sessions are logged and monitored
  - Failed login attempts are tracked
  - System resources are continuously monitored
  - Emergency procedures are available for administrators

For support, contact: operations@company.com

================================================================================
EOF

# Configure time synchronization
log "Configuring time synchronization..."
systemctl enable chronyd
systemctl start chronyd

# Add NTP servers
cat >> /etc/chrony.conf << 'EOF'
# Additional NTP servers for better time sync
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst
EOF

systemctl restart chronyd

# Configure system hardening
log "Applying system hardening..."

# Disable unused services
systemctl disable postfix 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

# Set strict file permissions
chmod 700 /root
chmod 700 /home/opc/.ssh
chmod 600 /home/opc/.ssh/authorized_keys 2>/dev/null || true

# Configure kernel parameters for security
cat >> /etc/sysctl.conf << 'EOF'
# Bastion host security hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
kernel.dmesg_restrict = 1
EOF

sysctl -p

# Create backup script for bastion configuration
log "Creating backup script..."
cat > /usr/local/bin/backup-bastion-config.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/bastion-backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/bastion-config-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Backup important configuration files
tar -czf "$BACKUP_FILE" \
    /etc/ssh/ \
    /etc/fail2ban/ \
    /etc/audit/ \
    /etc/motd \
    /etc/chrony.conf \
    /usr/local/bin/ \
    /var/log/bastion-*.log 2>/dev/null

# Keep only last 10 backups
ls -t "$BACKUP_DIR"/bastion-config-*.tar.gz | tail -n +11 | xargs rm -f 2>/dev/null

echo "Bastion configuration backup completed: $BACKUP_FILE"
EOF

chmod +x /usr/local/bin/backup-bastion-config.sh

# Schedule regular backups
echo "0 6 * * * /usr/local/bin/backup-bastion-config.sh >> /var/log/backup.log 2>&1" | crontab -

# Configure automatic security updates (for critical patches only)
log "Configuring automatic security updates..."
yum install -y yum-cron

cat > /etc/yum/yum-cron.conf << 'EOF'
[commands]
update_cmd = security
update_messages = yes
download_updates = yes
apply_updates = yes

[emitters]
system_name = None
emit_via = stdio

[email]
email_from = yum-cron@bastion
email_to = admin@company.com
email_host = localhost

[groups]
group_list = None
group_package_types = mandatory, default

[base]
debuglevel = -2
mdpolicy = group:main
EOF

systemctl enable yum-cron

# Final security checks and cleanup
log "Performing final security checks..."

# Remove unnecessary packages
yum remove -y telnet-server rsh-server ypbind tftp-server 2>/dev/null || true

# Ensure proper ownership of home directories
chown -R opc:opc /home/opc

# Create completion marker
log "Bastion host setup completed successfully"
touch /var/log/bastion-setup-complete
echo "$(date '+%Y-%m-%d %H:%M:%S') - Bastion setup completed for ${PROJECT_NAME} ${ENVIRONMENT}" > /var/log/bastion-setup-complete

# Restart SSH service to apply configuration
systemctl restart sshd
systemctl start fail2ban

# Final status report
log "=== BASTION HOST SETUP SUMMARY ==="
log "Project: ${PROJECT_NAME}"
log "Environment: ${ENVIRONMENT}"
log "SSH Configuration: Hardened"
log "Fail2ban: Enabled"
log "Firewall: Configured"
log "Audit Logging: Enabled"
log "Monitoring: Active"
log "Time Sync: Configured"
log "Security Hardening: Applied"
log "=== SETUP COMPLETE ==="

# Signal completion to the instance metadata
curl -X PUT -H 'Content-Type: text/plain' --data 'SUCCESS' "http://169.254.169.254/opc/v1/instance/metadata/bastion-setup-status" 2>/dev/null || true

log "Bastion host is ready for use. All services started successfully."
EOF
