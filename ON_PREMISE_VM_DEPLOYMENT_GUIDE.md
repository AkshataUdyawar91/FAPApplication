# On-Premise VM Deployment Guide
## Bajaj Document Processing System

Complete guide for deploying to any on-premise VM (not Azure).

---

## Prerequisites

### VM Requirements
- **OS**: Ubuntu 22.04 LTS or Windows Server 2022
- **CPU**: 4 cores minimum (8 cores recommended for production)
- **RAM**: 16 GB minimum (32 GB recommended for production)
- **Disk**: 256 GB SSD minimum
- **Network**: Static IP address, ports 80, 443, 22 (SSH) open

### Required Access
- Root/Administrator access to VM
- Internet connectivity for downloading packages
- Azure OpenAI API access (only external dependency)

---

## Part 1: Azure OpenAI Setup (Only External Service)

### Step 1: Get Azure OpenAI Access

**Option A: Use Existing Azure Subscription**
1. Go to https://portal.azure.com
2. Create Azure OpenAI resource (see previous guide)
3. Deploy models: gpt-4, gpt-4-vision, text-embedding-ada-002
4. Get endpoint and API key

**Option B: Request Access**
1. Apply at: https://aka.ms/oai/access
2. Wait for approval (usually 1-2 business days)
3. Follow Option A after approval

**Save These Values:**
```
Endpoint: https://your-resource.openai.azure.com/
API Key: [your-key]
Deployment Names: gpt-4, gpt-4-vision, text-embedding-ada-002
```

---

## Part 2: Ubuntu VM Setup

### Step 1: Connect to VM

```bash
# SSH to your VM
ssh username@your-vm-ip

# Update system
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install .NET 8 Runtime

```bash
# Download installer
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh

# Install .NET 8 runtime
./dotnet-install.sh --channel 8.0 --runtime aspnetcore

# Add to PATH
echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$PATH:$DOTNET_ROOT' >> ~/.bashrc
source ~/.bashrc

# Verify
dotnet --version
```

### Step 3: Install SQL Server

```bash
# Import Microsoft key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

# Add repository
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list)"

# Install
sudo apt-get update
sudo apt-get install -y mssql-server

# Configure
sudo /opt/mssql/bin/mssql-conf setup
```

**Configuration:**
- Choose: Developer Edition (free)
- Accept license: Yes
- Set SA password: [Create strong password]

```bash
# Install SQL tools
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install -y mssql-tools unixodbc-dev

# Add to PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

# Test
sqlcmd -S localhost -U sa -P 'YourPassword' -Q "SELECT @@VERSION"
```

### Step 4: Install Nginx

```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Step 5: Create Directories

```bash
sudo mkdir -p /var/www/bajaj-api
sudo mkdir -p /var/www/bajaj-frontend
sudo mkdir -p /var/bajaj-documents
sudo mkdir -p /var/backups/bajaj

sudo chown -R $USER:$USER /var/www/bajaj-api
sudo chown -R $USER:$USER /var/www/bajaj-frontend
sudo chown -R $USER:$USER /var/bajaj-documents
sudo chmod -R 755 /var/www
sudo chmod -R 755 /var/bajaj-documents
```

---

## Part 3: Database Setup

```bash
# Connect to SQL Server
sqlcmd -S localhost -U sa -P 'YourPassword'
```

```sql
CREATE DATABASE BajajDocumentProcessing;
GO
EXIT
```

---

## Part 4: Backend Deployment

### On Development Machine

```bash
cd backend
dotnet publish -c Release -o ./publish
cd publish
tar -czf bajaj-api.tar.gz *
```

### Transfer to VM

```bash
scp bajaj-api.tar.gz username@your-vm-ip:~/
```

### On VM

```bash
cd /var/www/bajaj-api
tar -xzf ~/bajaj-api.tar.gz

# Create configuration
nano appsettings.Production.json
```

**appsettings.Production.json:**
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=BajajDocumentProcessing;User Id=sa;Password=YourSQLPassword;TrustServerCertificate=True"
  },
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "ApiKey": "your-api-key",
    "DeploymentName": "gpt-4",
    "VisionDeploymentName": "gpt-4-vision",
    "EmbeddingDeploymentName": "text-embedding-ada-002"
  },
  "FileStorage": {
    "Type": "Local",
    "LocalPath": "/var/bajaj-documents",
    "MaxFileSizeMB": 10
  },
  "Email": {
    "Provider": "SMTP",
    "SmtpHost": "smtp.gmail.com",
    "SmtpPort": 587,
    "SmtpUsername": "your-email@gmail.com",
    "SmtpPassword": "your-app-password",
    "FromEmail": "noreply@bajaj.com"
  },
  "Jwt": {
    "SecretKey": "your-32-character-secret-key-here",
    "Issuer": "BajajDocumentProcessing",
    "Audience": "BajajDocumentProcessing",
    "ExpiryMinutes": 30
  }
}
```

### Create Systemd Service

```bash
sudo nano /etc/systemd/system/bajaj-api.service
```

```ini
[Unit]
Description=Bajaj Document Processing API
After=network.target mssql-server.service

[Service]
WorkingDirectory=/var/www/bajaj-api
ExecStart=/home/username/.dotnet/dotnet /var/www/bajaj-api/BajajDocumentProcessing.API.dll
Restart=always
RestartSec=10
User=username
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:5000

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable bajaj-api
sudo systemctl start bajaj-api
sudo systemctl status bajaj-api
```

### Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/bajaj-api
```

```nginx
server {
    listen 80;
    server_name your-vm-ip;
    client_max_body_size 20M;
    
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/bajaj-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Part 5: Frontend Deployment

### On Development Machine

```bash
cd frontend

# Update API endpoint
nano lib/core/constants/api_constants.dart
```

```dart
static const String API_BASE_URL = 'http://your-vm-ip';
```

```bash
flutter build web --release
cd build/web
tar -czf bajaj-frontend.tar.gz *
```

### Transfer to VM

```bash
scp bajaj-frontend.tar.gz username@your-vm-ip:~/
```

### On VM

```bash
cd /var/www/bajaj-frontend
tar -xzf ~/bajaj-frontend.tar.gz

sudo nano /etc/nginx/sites-available/bajaj-frontend
```

```nginx
server {
    listen 80 default_server;
    server_name your-vm-ip;
    root /var/www/bajaj-frontend;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

```bash
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/bajaj-frontend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Part 6: Testing

```bash
# Test API
curl http://your-vm-ip/api/health

# Test Frontend
# Open browser: http://your-vm-ip
```

---

## Part 7: Backup Script

```bash
nano ~/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/bajaj"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
sqlcmd -S localhost -U sa -P 'YourPassword' -Q \
  "BACKUP DATABASE BajajDocumentProcessing TO DISK = '$BACKUP_DIR/db_$DATE.bak'"

# Backup documents
tar -czf $BACKUP_DIR/docs_$DATE.tar.gz /var/bajaj-documents

# Delete old backups (>7 days)
find $BACKUP_DIR -type f -mtime +7 -delete
```

```bash
chmod +x ~/backup.sh

# Add to crontab (daily at 2 AM)
crontab -e
```

Add: `0 2 * * * /home/username/backup.sh`

---

## Quick Commands

```bash
# Restart API
sudo systemctl restart bajaj-api

# View logs
sudo journalctl -u bajaj-api -f

# Restart Nginx
sudo systemctl restart nginx

# Check services
sudo systemctl status bajaj-api
sudo systemctl status nginx
sudo systemctl status mssql-server
```

---

## Cost Summary

**One-time:**
- VM hardware/hosting: Variable

**Monthly:**
- Azure OpenAI only: ~$50-500 (usage-based)
- Everything else: Free (runs on your VM)

**Total: ~$50-500/month** (vs $340-700 with full Azure)

---

## Windows Server Alternative

If using Windows Server instead of Ubuntu:

1. Install .NET 8 Hosting Bundle
2. Install SQL Server Express/Developer
3. Install IIS instead of Nginx
4. Use Windows Services instead of systemd
5. Use Task Scheduler instead of cron

Full Windows guide available on request.
