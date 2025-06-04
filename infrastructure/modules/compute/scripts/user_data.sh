#!/bin/bash
# ====================================
# User Data Script for Library Application Servers
# Oracle Cloud Infrastructure (OCI)
# Book Library System
# ====================================

set -e  # Exit on any error

# Variables passed from Terraform
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
APP_PORT="${app_port}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/user-data.log
}

log "Starting user data script for ${PROJECT_NAME} ${ENVIRONMENT} environment"

# Update system packages
log "Updating system packages..."
yum update -y

# Install required packages
log "Installing required packages..."
yum install -y \
    python3 \
    python3-pip \
    python3-devel \
    gcc \
    git \
    wget \
    curl \
    unzip \
    htop \
    vim \
    nginx \
    supervisor \
    oracle-instantclient19.3-basic \
    oracle-instantclient19.3-devel \
    oracle-instantclient19.3-sqlplus

# Install Docker
log "Installing Docker..."
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker opc

# Install Docker Compose
log "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application user and directories
log "Creating application user and directories..."
useradd -m -s /bin/bash appuser
mkdir -p /opt/${PROJECT_NAME}
mkdir -p /var/log/${PROJECT_NAME}
mkdir -p /etc/${PROJECT_NAME}
mkdir -p /opt/${PROJECT_NAME}/static
mkdir -p /opt/${PROJECT_NAME}/media
mkdir -p /opt/${PROJECT_NAME}/backups

# Set ownership
chown -R appuser:appuser /opt/${PROJECT_NAME}
chown -R appuser:appuser /var/log/${PROJECT_NAME}
chown -R appuser:appuser /etc/${PROJECT_NAME}

# Install Python packages
log "Installing Python packages..."
pip3 install --upgrade pip
pip3 install virtualenv

# Create Python virtual environment
log "Creating Python virtual environment..."
sudo -u appuser python3 -m venv /opt/${PROJECT_NAME}/venv
sudo -u appuser /opt/${PROJECT_NAME}/venv/bin/pip install --upgrade pip

# Install application dependencies
log "Installing application dependencies..."
sudo -u appuser /opt/${PROJECT_NAME}/venv/bin/pip install \
    django==4.2.* \
    djangorestframework \
    django-cors-headers \
    djangorestframework-simplejwt \
    cx_Oracle \
    python-decouple \
    drf-spectacular \
    celery[redis] \
    django-filter \
    oracledb \
    gunicorn \
    whitenoise \
    psutil \
    requests

# Configure Oracle client
log "Configuring Oracle client..."
echo "/usr/lib/oracle/19.3/client64/lib" > /etc/ld.so.conf.d/oracle-instantclient.conf
ldconfig

# Set Oracle environment variables
cat >> /etc/environment << EOF
ORACLE_HOME=/usr/lib/oracle/19.3/client64
LD_LIBRARY_PATH=/usr/lib/oracle/19.3/client64/lib:$LD_LIBRARY_PATH
PATH=/usr/lib/oracle/19.3/client64/bin:$PATH
EOF

# Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Create Nginx server configuration
log "Creating Nginx server configuration..."
mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/${PROJECT_NAME}.conf << EOF
upstream ${PROJECT_NAME}_app {
    server 127.0.0.1:${APP_PORT};
}

server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Static files
    location /static/ {
        alias /opt/${PROJECT_NAME}/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias /opt/${PROJECT_NAME}/media/;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    # Health check endpoint
    location /health/ {
        access_log off;
        proxy_pass http://${PROJECT_NAME}_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
        proxy_read_timeout 5s;
    }
    
    # Application
    location / {
        proxy_pass http://${PROJECT_NAME}_app;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering on;
        proxy_buffer_size 8k;
        proxy_buffers 16 8k;
    }
}
EOF

# Create systemd service for the application
log "Creating systemd service..."
cat > /etc/systemd/system/${PROJECT_NAME}.service << EOF
[Unit]
Description=${PROJECT_NAME} Django Application
After=network.target
Requires=network.target

[Service]
Type=exec
User=appuser
Group=appuser
WorkingDirectory=/opt/${PROJECT_NAME}
Environment=PATH=/opt/${PROJECT_NAME}/venv/bin
Environment=DJANGO_SETTINGS_MODULE=${PROJECT_NAME}.settings.production
Environment=PYTHONDONTWRITEBYTECODE=1
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/${PROJECT_NAME}/venv/bin/gunicorn \\
    --bind 127.0.0.1:${APP_PORT} \\
    --workers 4 \\
    --worker-class gevent \\
    --worker-connections 1000 \\
    --max-requests 1000 \\
    --max-requests-jitter 100 \\
    --timeout 30 \\
    --keep-alive 2 \\
    --log-level info \\
    --log-file /var/log/${PROJECT_NAME}/gunicorn.log \\
    --access-logfile /var/log/${PROJECT_NAME}/access.log \\
    --error-logfile /var/log/${PROJECT_NAME}/error.log \\
    --capture-output \\
    ${PROJECT_NAME}.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Celery service for background tasks
log "Creating Celery service..."
cat > /etc/systemd/system/${PROJECT_NAME}-celery.service << EOF
[Unit]
Description=${PROJECT_NAME} Celery Worker
After=network.target redis.service
Requires=network.target

[Service]
Type=exec
User=appuser
Group=appuser
WorkingDirectory=/opt/${PROJECT_NAME}
Environment=PATH=/opt/${PROJECT_NAME}/venv/bin
Environment=DJANGO_SETTINGS_MODULE=${PROJECT_NAME}.settings.production
Environment=PYTHONDONTWRITEBYTECODE=1
Environment=PYTHONUNBUFFERED=1
ExecStart=/opt/${PROJECT_NAME}/venv/bin/celery -A ${PROJECT_NAME} worker \\
    --loglevel=info \\
    --logfile=/var/log/${PROJECT_NAME}/celery.log \\
    --concurrency=2
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=10
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Install and configure monitoring agent
log "Installing monitoring agent..."
cat > /opt/${PROJECT_NAME}/health_check.py << 'EOF'
#!/usr/bin/env python3
import json
import sys
import time
import psutil
import requests
from datetime import datetime

def check_application_health():
    """Check application health"""
    try:
        response = requests.get('http://localhost:8000/health/', timeout=5)
        return response.status_code == 200
    except:
        return False

def check_system_health():
    """Check system health metrics"""
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return {
        'cpu_percent': cpu_percent,
        'memory_percent': memory.percent,
        'disk_percent': (disk.used / disk.total) * 100,
        'timestamp': datetime.now().isoformat()
    }

def main():
    health_data = {
        'application_healthy': check_application_health(),
        'system_metrics': check_system_health()
    }
    
    print(json.dumps(health_data))
    
    # Exit with error code if application is not healthy
    if not health_data['application_healthy']:
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

chmod +x /opt/${PROJECT_NAME}/health_check.py

# Create health check service
cat > /etc/systemd/system/${PROJECT_NAME}-health.service << EOF
[Unit]
Description=${PROJECT_NAME} Health Check
After=network.target

[Service]
Type=oneshot
User=appuser
Group=appuser
ExecStart=/opt/${PROJECT_NAME}/venv/bin/python /opt/${PROJECT_NAME}/health_check.py
StandardOutput=journal
StandardError=journal
EOF

# Create health check timer
cat > /etc/systemd/system/${PROJECT_NAME}-health.timer << EOF
[Unit]
Description=${PROJECT_NAME} Health Check Timer
Requires=${PROJECT_NAME}-health.service

[Timer]
OnCalendar=*:*:00,30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Configure log rotation
log "Configuring log rotation..."
cat > /etc/logrotate.d/${PROJECT_NAME} << EOF
/var/log/${PROJECT_NAME}/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 appuser appuser
    postrotate
        systemctl reload ${PROJECT_NAME} > /dev/null 2>&1 || true
    endscript
}
EOF

# Install CloudWatch agent (if needed)
if [[ "${ENVIRONMENT}" == "production" ]]; then
    log "Installing CloudWatch agent..."
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/oracle_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    rm -f ./amazon-cloudwatch-agent.rpm
fi

# Configure firewall
log "Configuring firewall..."
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=${APP_PORT}/tcp
firewall-cmd --reload

# Enable and start services
log "Enabling and starting services..."
systemctl daemon-reload
systemctl enable nginx
systemctl enable ${PROJECT_NAME}
systemctl enable ${PROJECT_NAME}-celery
systemctl enable ${PROJECT_NAME}-health.timer

# Create deployment script
log "Creating deployment script..."
cat > /opt/${PROJECT_NAME}/deploy.sh << 'EOF'
#!/bin/bash
set -e

PROJECT_NAME=$(basename $(pwd))
APP_PORT=8000

echo "Starting deployment for ${PROJECT_NAME}..."

# Pull latest code (this would be handled by CI/CD in real deployment)
# git pull origin main

# Install/update dependencies
./venv/bin/pip install -r requirements.txt

# Collect static files
./venv/bin/python manage.py collectstatic --noinput

# Run database migrations
./venv/bin/python manage.py migrate --noinput

# Restart services
sudo systemctl restart ${PROJECT_NAME}
sudo systemctl restart ${PROJECT_NAME}-celery
sudo systemctl reload nginx

echo "Deployment completed successfully!"
EOF

chmod +x /opt/${PROJECT_NAME}/deploy.sh
chown appuser:appuser /opt/${PROJECT_NAME}/deploy.sh

# Create backup script
log "Creating backup script..."
cat > /opt/${PROJECT_NAME}/backup.sh << 'EOF'
#!/bin/bash
set -e

PROJECT_NAME=$(basename $(pwd))
BACKUP_DIR="/opt/${PROJECT_NAME}/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starting backup for ${PROJECT_NAME}..."

# Create backup directory for this run
mkdir -p "${BACKUP_DIR}/${DATE}"

# Backup media files
tar -czf "${BACKUP_DIR}/${DATE}/media_${DATE}.tar.gz" -C /opt/${PROJECT_NAME} media/

# Backup static files
tar -czf "${BACKUP_DIR}/${DATE}/static_${DATE}.tar.gz" -C /opt/${PROJECT_NAME} static/

# Backup logs
tar -czf "${BACKUP_DIR}/${DATE}/logs_${DATE}.tar.gz" -C /var/log ${PROJECT_NAME}/

# Remove backups older than 7 days
find "${BACKUP_DIR}" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

echo "Backup completed successfully!"
EOF

chmod +x /opt/${PROJECT_NAME}/backup.sh
chown appuser:appuser /opt/${PROJECT_NAME}/backup.sh

# Set up backup cron job
echo "0 2 * * * /opt/${PROJECT_NAME}/backup.sh >> /var/log/${PROJECT_NAME}/backup.log 2>&1" | sudo -u appuser crontab -

# Create monitoring dashboard
log "Creating simple monitoring dashboard..."
cat > /opt/${PROJECT_NAME}/monitor.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Library System Monitor</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .healthy { background-color: #d4edda; color: #155724; }
        .unhealthy { background-color: #f8d7da; color: #721c24; }
        .metric { display: inline-block; margin: 10px; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Library System Status</h1>
    <div id="status"></div>
    <script>
        function updateStatus() {
            fetch('/health/')
                .then(response => response.json())
                .then(data => {
                    const statusDiv = document.getElementById('status');
                    statusDiv.innerHTML = JSON.stringify(data, null, 2);
                })
                .catch(error => {
                    console.error('Error:', error);
                });
        }
        updateStatus();
        setInterval(updateStatus, 30000);
    </script>
</body>
</html>
EOF

# Final system configuration
log "Performing final system configuration..."

# Set timezone
timedatectl set-timezone UTC

# Update system limits
cat >> /etc/security/limits.conf << EOF
appuser soft nofile 65536
appuser hard nofile 65536
appuser soft nproc 32768
appuser hard nproc 32768
EOF

# Configure kernel parameters
cat >> /etc/sysctl.conf << EOF
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
vm.swappiness = 10
EOF

sysctl -p

# Signal completion
log "User data script completed successfully for ${PROJECT_NAME} ${ENVIRONMENT}"

# Create completion marker
touch /var/log/user-data-complete
echo "$(date '+%Y-%m-%d %H:%M:%S') - User data script completed" > /var/log/user-data-complete

# Start services (nginx will be started by the deployment process)
systemctl start nginx

log "Server initialization complete. Ready for application deployment."
EOF
