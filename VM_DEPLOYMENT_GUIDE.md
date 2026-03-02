# Complete VM Deployment Guide
## Bajaj Document Processing System

This guide provides step-by-step instructions for deploying the complete system to an Azure Virtual Machine.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure VM Setup](#azure-vm-setup)
3. [Azure OpenAI Setup](#azure-openai-setup)
4. [VM Software Installation](#vm-software-installation)
5. [Database Setup](#database-setup)
6. [Backend Deployment](#backend-deployment)
7. [Frontend Deployment](#frontend-deployment)
8. [SSL/HTTPS Configuration](#ssl-https-configuration)
9. [Monitoring & Maintenance](#monitoring--maintenance)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Your Development Machine
- .NET 8 SDK installed
- Flutter SDK installed
- Git installed
- SSH client (PuTTY for Windows, built-in for Mac/Linux)

### Azure Account
- Active Azure subscription
- Access to create resources

---

## Azure VM Setup

### Step 1: Create Virtual Machine

1. **Login to Azure Portal**
   - Navigate to: https://portal.azure.com

2. **Create VM**
   - Click "Create a resource" → "Virtual Machine"
   - Configure:

```
Basics:
  Subscription: [Your subscription]
  Resource Group: Create new → "bajaj-rg"
  Virtual machine name: bajaj-vm
  Region: Central India (or nearest)
  Image: Ubuntu Server 22.04 LTS - x64 Gen2
  Size: Standard_D4s_v3 (4 vCPU, 16 GB RAM)
  
Authentication:
  Authentication type: SSH public key
  Username: azureuser
  SSH public key source: Generate new key pair
  Key pair name: bajaj-vm-key
  
Inbound port rules:
  Public inbound ports: Allow selected ports
  Select inbound ports: HTTP (80), HTTPS (443), SSH (22)
```

3. **Configure Disks**
   - OS disk type: Premium SSD
   - Size: 128 GB (or 256 GB for production)

4. **Configure Networking**
   - Virtual network: Create new → "bajaj-vnet"
   - Subnet: default
   - Public IP: Create new → "bajaj-vm-ip"
   - NIC network security group: Basic
   - Public inbound ports: HTTP, HTTPS, SSH

5. **Review + Create**
   - Click "Review + create"
   - Download the private key (.pem file) when prompted
   - Click "Create"

6. **Save Connection Details**
   - After deployment, note the Public IP address
   - Example: `20.204.123.45`

### Step 2: Connect to VM

**For Linux/Mac:**
```bash
# Set permissions on private key
chmod 400 ~/Downloads/bajaj-vm-key.pem

# Connect to VM
ssh -i ~/Downloads/bajaj-vm-key.pem azureuser@20.204.123.45
```

**For Windows (using PuTTY):**
1. Convert .pem to .ppk using PuTTYgen
2. Open PuTTY
3. Host: `azureuser@20.204.123.45`
4. Connection → SSH → Auth → Browse to .ppk file
5. Click "Open"

---

## Azure OpenAI Setup

### Step 1: Create Azure OpenAI Resource

1. **In Azure Portal**
   - Create a resource → Search "Azure OpenAI"
   - Click "Create"

```
Basics:
  Subscription: [Your subscription]
  Resource Group: bajaj-rg
  Region: East US (or Sweden Central for GPT-4)
  Name: bajaj-openai
  Pricing tier: Standard S0
```

2. **Deploy Models**
   - After creation, go to Azure OpenAI Studio
   - Click "Deployments" → "Create new deployment"

**Deploy GPT-4:**
```
Model: gpt-4 (0613 or later)
Deployment name: gpt-4
Tokens per minute rate limit: 10K
```

**Deploy GPT-4 Vision:**
```
Model: gpt-4-vision-preview
Deployment name: gpt-4-vision
Tokens per minute rate limit: 10K
```

**Deploy Embeddings:**
```
Model: text-embedding-ada-002
Deployment name: text-embedding-ada-002
Tokens per minute rate limit: 120K
```

3. **Get Credentials**
   - Navigate to: Resource → Keys and Endpoint
   - Copy and save:
     - **Endpoint**: `https://bajaj-openai.openai.azure.com/`
     - **Key 1**: `[your-api-key]`

---

## VM Software Installation

### Step 1: Update System

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git unzip
```

### Step 2: Install .NET 8 Runtime

```bash
# Download and install .NET 8
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0 --runtime aspnetcore

# Add to PATH
echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools' >> ~/.bashrc
source ~/.bashrc

# Verify installation
dotnet --version
```

### Step 3: Install SQL Server

```bash
# Import Microsoft GPG key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

# Add SQL Server repository
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list)"

# Install SQL Server
sudo apt-get update
sudo apt-get install -y mssql-server

# Configure SQL Server
sudo /opt/mssql/bin/mssql-conf setup
```

**Configuration prompts:**
```
Choose edition:
  2) Developer (free, no production use rights)

Accept license terms: Yes

Enter SQL Server system administrator password: [Create strong password]
Confirm password: [Repeat password]
```

**Save these credentials:**
- Username: `sa`
- Password: `[your-password]`

```bash
# Verify SQL Server is running
systemctl status mssql-server

# Install SQL Server command-line tools
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install -y mssql-tools unixodbc-dev

# Add to PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

# Test connection
sqlcmd -S localhost -U sa -P '[your-password]' -Q "SELECT @@VERSION"
```

### Step 4: Install Nginx

```bash
# Install Nginx
sudo apt install -y nginx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify installation
sudo systemctl status nginx

# Test - should see Nginx welcome page
curl http://localhost
```

### Step 5: Create Application Directories

```bash
# Create directories
sudo mkdir -p /var/www/bajaj-api
sudo mkdir -p /var/www/bajaj-frontend
sudo mkdir -p /var/bajaj-documents

# Set ownership
sudo chown -R $USER:$USER /var/www/bajaj-api
sudo chown -R $USER:$USER /var/www/bajaj-frontend
sudo chown -R $USER:$USER /var/bajaj-documents

# Set permissions
sudo chmod -R 755 /var/www
sudo chmod -R 755 /var/bajaj-documents
```

---

## Database Setup

### Step 1: Create Database

```bash
# Connect to SQL Server
sqlcmd -S localhost -U sa -P '[your-password]'
```

```sql
-- Create database
CREATE DATABASE BajajDocumentProcessing;
GO

-- Verify database created
SELECT name FROM sys.databases;
GO

-- Exit
EXIT
```

### Step 2: Configure Firewall (if needed)

```bash
# Allow SQL Server through firewall
sudo ufw allow 1433/tcp
```

---

## Backend Deployment

### Step 1: Prepare Application on Development Machine

```bash
# Navigate to backend directory
cd backend

# Restore dependencies
dotnet restore

# Run tests (optional but recommended)
dotnet test

# Publish application
dotnet publish -c Release -o ./publish

# Create deployment package
cd publish
tar -czf bajaj-api.tar.gz *
```

### Step 2: Transfer to VM

```bash
# From your development machine
scp -i ~/Downloads/bajaj-vm-key.pem bajaj-api.tar.gz azureuser@20.204.123.45:~/
```

### Step 3: Extract and Configure on VM

```bash
# On VM - Extract files
cd /var/www/bajaj-api
tar -xzf ~/bajaj-api.tar.gz

# Create appsettings.Production.json
nano appsettings.Production.json
```

**appsettings.Production.json:**
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=BajajDocumentProcessing;User Id=sa;Password=YOUR_SQL_PASSWORD;TrustServerCertificate=True;MultipleActiveResultSets=true"
  },
  "AzureOpenAI": {
    "Endpoint": "https://bajaj-openai.openai.azure.com/",
    "ApiKey": "YOUR_OPENAI_API_KEY",
    "DeploymentName": "gpt-4",
    "VisionDeploymentName": "gpt-4-vision",
    "EmbeddingDeploymentName": "text-embedding-ada-002",
    "MaxTokens": 4000,
    "Temperature": 0.7
  },
  "FileStorage": {
    "Type": "Local",
    "LocalPath": "/var/bajaj-documents",
    "MaxFileSizeMB": 10,
    "AllowedExtensions": [".pdf", ".jpg", ".jpeg", ".png"]
  },
  "Email": {
    "Provider": "SMTP",
    "SmtpHost": "smtp.gmail.com",
    "SmtpPort": 587,
    "SmtpUsername": "your-email@gmail.com",
    "SmtpPassword": "your-app-password",
    "FromEmail": "noreply@bajaj.com",
    "FromName": "Bajaj Document Processing",
    "EnableSsl": true
  },
  "Jwt": {
    "SecretKey": "your-secret-key-minimum-32-characters-long-change-this",
    "Issuer": "BajajDocumentProcessing",
    "Audience": "BajajDocumentProcessing",
    "ExpiryMinutes": 30
  },
  "SAP": {
    "BaseUrl": "https://your-sap-server.com/odata/v4",
    "Username": "sap-user",
    "Password": "sap-password",
    "Timeout": 30
  },
  "Cors": {
    "AllowedOrigins": [
      "http://20.204.123.45",
      "http://yourdomain.com"
    ]
  }
}
```

**Important: Replace these values:**
- `YOUR_SQL_PASSWORD` - Your SQL Server password
- `YOUR_OPENAI_API_KEY` - Your Azure OpenAI API key
- `your-email@gmail.com` - Your Gmail address
- `your-app-password` - Gmail app password (see below)
- `your-secret-key...` - Generate a random 32+ character string
- `20.204.123.45` - Your VM's public IP

**Gmail App Password Setup:**
1. Go to Google Account → Security
2. Enable 2-Step Verification
3. Go to App Passwords
4. Generate password for "Mail"
5. Use this password in config

### Step 4: Run Database Migrations

```bash
# Navigate to API directory
cd /var/www/bajaj-api

# Run migrations
dotnet BajajDocumentProcessing.API.dll --migrate

# Or manually using EF Core tools
dotnet ef database update --project BajajDocumentProcessing.API.dll
```

### Step 5: Create Systemd Service

```bash
# Create service file
sudo nano /etc/systemd/system/bajaj-api.service
```

**Service configuration:**
```ini
[Unit]
Description=Bajaj Document Processing API
After=network.target mssql-server.service

[Service]
WorkingDirectory=/var/www/bajaj-api
ExecStart=/home/azureuser/.dotnet/dotnet /var/www/bajaj-api/BajajDocumentProcessing.API.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=bajaj-api
User=azureuser
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_URLS=http://localhost:5000

[Install]
WantedBy=multi-user.target
```

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable bajaj-api

# Start service
sudo systemctl start bajaj-api

# Check status
sudo systemctl status bajaj-api

# View logs
sudo journalctl -u bajaj-api -f
```

### Step 6: Configure Nginx for Backend

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/bajaj-api
```

**Nginx configuration:**
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;  # Or use IP: 20.204.123.45
    
    # Increase timeouts for large file uploads
    client_max_body_size 20M;
    proxy_read_timeout 300;
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:5000/health;
        access_log off;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/bajaj-api /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Test API
curl http://localhost/health
```

---

## Frontend Deployment

### Step 1: Build Flutter Web App

**On your development machine:**

```bash
# Navigate to frontend directory
cd frontend

# Update API endpoint
nano lib/core/constants/api_constants.dart
```

**Update API_BASE_URL:**
```dart
class ApiConstants {
  static const String API_BASE_URL = 'http://20.204.123.45';  // Your VM IP
  static const int TIMEOUT_SECONDS = 30;
  
  // API Endpoints
  static const String LOGIN = '/api/auth/login';
  static const String REFRESH_TOKEN = '/api/auth/refresh';
  // ... rest of endpoints
}
```

```bash
# Install dependencies
flutter pub get

# Build for web
flutter build web --release

# Create deployment package
cd build/web
tar -czf bajaj-frontend.tar.gz *
```

### Step 2: Transfer to VM

```bash
# From your development machine
scp -i ~/Downloads/bajaj-vm-key.pem bajaj-frontend.tar.gz azureuser@20.204.123.45:~/
```

### Step 3: Extract on VM

```bash
# On VM
cd /var/www/bajaj-frontend
tar -xzf ~/bajaj-frontend.tar.gz

# Set permissions
sudo chown -R www-data:www-data /var/www/bajaj-frontend
sudo chmod -R 755 /var/www/bajaj-frontend
```

### Step 4: Configure Nginx for Frontend

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/bajaj-frontend
```

**Nginx configuration:**
```nginx
server {
    listen 80 default_server;
    server_name yourdomain.com www.yourdomain.com;  # Or use IP
    
    root /var/www/bajaj-frontend;
    index index.html;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json;
    
    location / {
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Disable caching for index.html
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        expires 0;
    }
}
```

```bash
# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Enable site
sudo ln -s /etc/nginx/sites-available/bajaj-frontend /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Test frontend
curl http://localhost
```

---

## SSL/HTTPS Configuration

### Option 1: Let's Encrypt (Free SSL) - Recommended

**Prerequisites:**
- Domain name pointing to your VM IP
- Ports 80 and 443 open

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com -d api.yourdomain.com

# Follow prompts:
# - Enter email address
# - Agree to terms
# - Choose to redirect HTTP to HTTPS (recommended)

# Test auto-renewal
sudo certbot renew --dry-run

# Certificates auto-renew via cron job
```

### Option 2: Self-Signed Certificate (Development Only)

```bash
# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/bajaj-selfsigned.key \
  -out /etc/ssl/certs/bajaj-selfsigned.crt

# Update Nginx configuration
sudo nano /etc/nginx/sites-available/bajaj-frontend
```

**Add SSL configuration:**
```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;
    
    ssl_certificate /etc/ssl/certs/bajaj-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/bajaj-selfsigned.key;
    
    # ... rest of configuration
}

server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

```bash
# Reload Nginx
sudo systemctl reload nginx
```

---

## Monitoring & Maintenance

### Step 1: Setup Log Rotation

```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/bajaj-api
```

```
/var/log/bajaj-api/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 azureuser azureuser
    sharedscripts
    postrotate
        systemctl reload bajaj-api > /dev/null 2>&1 || true
    endscript
}
```

### Step 2: Setup Monitoring Script

```bash
# Create monitoring script
nano ~/monitor-bajaj.sh
```

```bash
#!/bin/bash

# Check API service
if ! systemctl is-active --quiet bajaj-api; then
    echo "$(date): API service is down. Restarting..." >> /var/log/bajaj-monitor.log
    sudo systemctl restart bajaj-api
fi

# Check Nginx
if ! systemctl is-active --quiet nginx; then
    echo "$(date): Nginx is down. Restarting..." >> /var/log/bajaj-monitor.log
    sudo systemctl restart nginx
fi

# Check SQL Server
if ! systemctl is-active --quiet mssql-server; then
    echo "$(date): SQL Server is down. Restarting..." >> /var/log/bajaj-monitor.log
    sudo systemctl restart mssql-server
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "$(date): Disk usage is at ${DISK_USAGE}%" >> /var/log/bajaj-monitor.log
fi
```

```bash
# Make executable
chmod +x ~/monitor-bajaj.sh

# Add to crontab (runs every 5 minutes)
crontab -e
```

**Add line:**
```
*/5 * * * * /home/azureuser/monitor-bajaj.sh
```

### Step 3: Backup Script

```bash
# Create backup script
nano ~/backup-bajaj.sh
```

```bash
#!/bin/bash

BACKUP_DIR="/var/backups/bajaj"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
sqlcmd -S localhost -U sa -P 'YOUR_SQL_PASSWORD' -Q "BACKUP DATABASE BajajDocumentProcessing TO DISK = '$BACKUP_DIR/db_$DATE.bak'"

# Backup documents
tar -czf $BACKUP_DIR/documents_$DATE.tar.gz /var/bajaj-documents

# Backup configuration
tar -czf $BACKUP_DIR/config_$DATE.tar.gz /var/www/bajaj-api/appsettings.Production.json

# Delete backups older than 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

echo "$(date): Backup completed" >> /var/log/bajaj-backup.log
```

```bash
# Make executable
chmod +x ~/backup-bajaj.sh

# Add to crontab (runs daily at 2 AM)
crontab -e
```

**Add line:**
```
0 2 * * * /home/azureuser/backup-bajaj.sh
```

### Step 4: View Logs

```bash
# API logs
sudo journalctl -u bajaj-api -f

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# SQL Server logs
sudo tail -f /var/opt/mssql/log/errorlog
```

---

## Troubleshooting

### API Not Starting

```bash
# Check service status
sudo systemctl status bajaj-api

# View detailed logs
sudo journalctl -u bajaj-api -n 100 --no-pager

# Check if port is in use
sudo netstat -tulpn | grep 5000

# Test API manually
cd /var/www/bajaj-api
dotnet BajajDocumentProcessing.API.dll
```

### Database Connection Issues

```bash
# Check SQL Server status
systemctl status mssql-server

# Test connection
sqlcmd -S localhost -U sa -P 'YOUR_PASSWORD' -Q "SELECT @@VERSION"

# Check firewall
sudo ufw status

# View SQL Server logs
sudo tail -f /var/opt/mssql/log/errorlog
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# Check status
sudo systemctl status nginx

# View error logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx
```

### File Upload Issues

```bash
# Check directory permissions
ls -la /var/bajaj-documents

# Fix permissions
sudo chown -R azureuser:azureuser /var/bajaj-documents
sudo chmod -R 755 /var/bajaj-documents

# Check disk space
df -h
```

### High Memory Usage

```bash
# Check memory usage
free -h

# Check processes
top

# Restart services
sudo systemctl restart bajaj-api
sudo systemctl restart nginx
```

---

## Performance Optimization

### Step 1: Configure SQL Server Memory

```bash
# Connect to SQL Server
sqlcmd -S localhost -U sa -P 'YOUR_PASSWORD'
```

```sql
-- Set max memory to 8GB (adjust based on your VM)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory', 8192;
RECONFIGURE;
GO
```

### Step 2: Enable Response Compression

Already configured in Nginx with gzip.

### Step 3: Setup Redis Cache (Optional)

```bash
# Install Redis
sudo apt install -y redis-server

# Configure Redis
sudo nano /etc/redis/redis.conf
```

**Update:**
```
maxmemory 256mb
maxmemory-policy allkeys-lru
```

```bash
# Restart Redis
sudo systemctl restart redis-server

# Enable on boot
sudo systemctl enable redis-server
```

**Update appsettings.Production.json:**
```json
{
  "Redis": {
    "ConnectionString": "localhost:6379",
    "InstanceName": "BajajCache"
  }
}
```

---

## Security Hardening

### Step 1: Configure Firewall

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check status
sudo ufw status
```

### Step 2: Disable Root Login

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config
```

**Update:**
```
PermitRootLogin no
PasswordAuthentication no
```

```bash
# Restart SSH
sudo systemctl restart sshd
```

### Step 3: Setup Fail2Ban

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Create local config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit config
sudo nano /etc/fail2ban/jail.local
```

**Update:**
```ini
[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 3600
```

```bash
# Start Fail2Ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban
```

---

## Quick Reference Commands

### Service Management
```bash
# Start/Stop/Restart API
sudo systemctl start bajaj-api
sudo systemctl stop bajaj-api
sudo systemctl restart bajaj-api

# View API logs
sudo journalctl -u bajaj-api -f

# Restart Nginx
sudo systemctl restart nginx

# Restart SQL Server
sudo systemctl restart mssql-server
```

### Deployment Updates
```bash
# Backend update
cd /var/www/bajaj-api
# Upload new files
sudo systemctl restart bajaj-api

# Frontend update
cd /var/www/bajaj-frontend
# Upload new files
sudo systemctl reload nginx
```

### Database Operations
```bash
# Backup database
sqlcmd -S localhost -U sa -P 'PASSWORD' -Q "BACKUP DATABASE BajajDocumentProcessing TO DISK = '/var/backups/db.bak'"

# Restore database
sqlcmd -S localhost -U sa -P 'PASSWORD' -Q "RESTORE DATABASE BajajDocumentProcessing FROM DISK = '/var/backups/db.bak'"
```

---

## Testing Deployment

### Step 1: Test Backend API

```bash
# Health check
curl http://YOUR_VM_IP/health

# Test login (should return 401 or validation error)
curl -X POST http://YOUR_VM_IP/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

### Step 2: Test Frontend

```bash
# Open in browser
http://YOUR_VM_IP

# Should see login page
```

### Step 3: Test File Upload

1. Login to application
2. Navigate to document upload
3. Upload a test PDF
4. Check file exists:
```bash
ls -la /var/bajaj-documents
```

---

## Support & Maintenance

### Regular Maintenance Tasks

**Daily:**
- Check service status
- Review error logs
- Monitor disk space

**Weekly:**
- Review backup logs
- Check for system updates
- Review security logs

**Monthly:**
- Apply system updates
- Review and optimize database
- Test backup restoration

### System Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update .NET runtime (if needed)
./dotnet-install.sh --channel 8.0 --runtime aspnetcore

# Restart services after updates
sudo systemctl restart bajaj-api
sudo systemctl restart nginx
```

---

## Cost Summary

### Monthly Costs (Estimated)

**Development VM:**
- VM (D2s_v3): ~$70-100/month
- Azure OpenAI: ~$50-100/month
- **Total: ~$120-200/month**

**Production VM:**
- VM (D4s_v3): ~$140-200/month
- Azure OpenAI: ~$200-500/month
- **Total: ~$340-700/month**

---

## Conclusion

Your Bajaj Document Processing System is now deployed and running on Azure VM!

**Access URLs:**
- Frontend: `http://YOUR_VM_IP` or `https://yourdomain.com`
- Backend API: `http://YOUR_VM_IP/api` or `https://api.yourdomain.com`
- API Health: `http://YOUR_VM_IP/health`

**Next Steps:**
1. Configure domain name (optional)
2. Setup SSL certificate
3. Create initial users
4. Test all features
5. Setup monitoring alerts
6. Configure automated backups

For issues or questions, refer to the Troubleshooting section above.
