# Deployment Guide

Production deployment guide for ChainForge.

**⚠️ Warning:** ChainForge is an educational project. Use caution when deploying to production.

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Ruby 3.2.2
- MongoDB 4.4+
- Nginx or Apache
- SSL certificate
- Domain name

## Environment Setup

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev

# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-installer | bash

# Add to ~/.bashrc
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.2.2
rbenv install 3.2.2
rbenv global 3.2.2
```

### 2. MongoDB Installation

```bash
# Import MongoDB GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Install MongoDB
sudo apt update
sudo apt install -y mongodb-org

# Start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

### 3. MongoDB Security

```bash
# Connect to MongoDB
mongo

# Create admin user
use admin
db.createUser({
  user: "admin",
  pwd: "STRONG_PASSWORD_HERE",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})

# Create app user
use chain_forge
db.createUser({
  user: "chainforge_user",
  pwd: "STRONG_PASSWORD_HERE",
  roles: [ { role: "readWrite", db: "chain_forge" } ]
})

exit
```

Enable authentication in `/etc/mongod.conf`:
```yaml
security:
  authorization: enabled
```

Restart MongoDB:
```bash
sudo systemctl restart mongod
```

## Application Deployment

### 1. Clone Repository

```bash
cd /var/www
sudo git clone https://github.com/Perafan18/chain_forge.git
cd chain_forge
sudo chown -R $USER:$USER .
```

### 2. Install Dependencies

```bash
bundle install --deployment --without development test
```

### 3. Environment Configuration

Create `.env` file:
```bash
cat > .env << EOF
MONGO_DB_NAME=chain_forge
MONGO_DB_HOST=localhost
MONGO_DB_PORT=27017
MONGO_DB_USER=chainforge_user
MONGO_DB_PASSWORD=STRONG_PASSWORD_HERE
ENVIRONMENT=production
DEFAULT_DIFFICULTY=4
RACK_ENV=production
EOF

chmod 600 .env
```

### 4. MongoDB Configuration

Update `config/mongoid.yml` for production:
```yaml
production:
  clients:
    default:
      database: <%= ENV['MONGO_DB_NAME'] %>
      hosts:
        - <%= "#{ENV['MONGO_DB_HOST']}:#{ENV['MONGO_DB_PORT']}" %>
      options:
        user: <%= ENV['MONGO_DB_USER'] %>
        password: <%= ENV['MONGO_DB_PASSWORD'] %>
        auth_source: admin
```

## Process Management

### Using Systemd

Create `/etc/systemd/system/chainforge.service`:
```ini
[Unit]
Description=ChainForge Blockchain API
After=network.target mongod.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/chain_forge
Environment=RACK_ENV=production
ExecStart=/home/www-data/.rbenv/shims/bundle exec rackup -p 1910 -o 127.0.0.1
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable chainforge
sudo systemctl start chainforge
sudo systemctl status chainforge
```

## Reverse Proxy

### Nginx Configuration

Create `/etc/nginx/sites-available/chainforge`:
```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
limit_req_zone $binary_remote_addr zone=chain:10m rate=10r/m;
limit_req_zone $binary_remote_addr zone=block:10m rate=30r/m;

upstream chainforge {
    server 127.0.0.1:1910 fail_timeout=0;
}

server {
    listen 80;
    server_name api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Logging
    access_log /var/log/nginx/chainforge_access.log;
    error_log /var/log/nginx/chainforge_error.log;

    # Proxy to application
    location /api/v1/ {
        limit_req zone=api burst=10 nodelay;

        proxy_pass http://chainforge;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts (mining can take time)
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Rate limiting for specific endpoints
    location /api/v1/chain {
        limit_req zone=chain burst=5 nodelay;
        proxy_pass http://chainforge;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location ~ /api/v1/chain/.*/block$ {
        limit_req zone=block burst=10 nodelay;
        proxy_pass http://chainforge;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Longer timeout for mining
        proxy_read_timeout 600s;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/chainforge /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## SSL Certificate

### Using Let's Encrypt

```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d api.yourdomain.com

# Auto-renewal (already configured by certbot)
sudo certbot renew --dry-run
```

## Firewall

```bash
# Allow SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Block direct access to app port
sudo ufw deny 1910/tcp

# Enable firewall
sudo ufw enable
```

## Monitoring

### Application Logs

```bash
# View application logs
sudo journalctl -u chainforge -f

# View nginx logs
sudo tail -f /var/log/nginx/chainforge_access.log
sudo tail -f /var/log/nginx/chainforge_error.log
```

### MongoDB Monitoring

```bash
# MongoDB logs
sudo tail -f /var/log/mongodb/mongod.log

# Connection check
mongo --host localhost --port 27017 -u admin -p --authenticationDatabase admin
```

### System Resources

```bash
# CPU and memory
htop

# Disk space
df -h

# MongoDB disk usage
du -sh /var/lib/mongodb
```

## Backup

### MongoDB Backup

```bash
# Create backup script
cat > /usr/local/bin/backup-chainforge.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/var/backups/chainforge
mkdir -p $BACKUP_DIR

mongodump \
  --host localhost \
  --port 27017 \
  --db chain_forge \
  --username chainforge_user \
  --password STRONG_PASSWORD_HERE \
  --authenticationDatabase admin \
  --out $BACKUP_DIR/backup_$DATE

# Keep only last 7 days
find $BACKUP_DIR -type d -mtime +7 -exec rm -rf {} +
EOF

chmod +x /usr/local/bin/backup-chainforge.sh
```

Add to crontab:
```bash
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-chainforge.sh
```

## Performance Tuning

### MongoDB Indexes

```javascript
// Connect to MongoDB
mongo -u chainforge_user -p --authenticationDatabase admin

use chain_forge

// Create indexes
db.blocks.createIndex({ "blockchain_id": 1 })
db.blocks.createIndex({ "index": 1 })
db.blocks.createIndex({ "_hash": 1 })
db.blockchains.createIndex({ "created_at": -1 })
```

### Application Tuning

Update `.env`:
```bash
# Increase default difficulty for production
DEFAULT_DIFFICULTY=4

# Production environment
RACK_ENV=production
```

### System Tuning

```bash
# Increase file descriptors
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# MongoDB tuning
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
```

## Security Checklist

- [ ] MongoDB authentication enabled
- [ ] Strong passwords configured
- [ ] SSL/TLS certificates installed
- [ ] Firewall configured
- [ ] Application running as non-root user
- [ ] `.env` file permissions set to 600
- [ ] Nginx security headers configured
- [ ] Rate limiting enabled
- [ ] Regular backups scheduled
- [ ] Monitoring configured
- [ ] Log rotation enabled
- [ ] System updates automated

## Troubleshooting

### Application Won't Start

```bash
# Check logs
sudo journalctl -u chainforge -n 50

# Check if port is in use
sudo lsof -i :1910

# Check MongoDB connection
mongo -u chainforge_user -p --authenticationDatabase admin

# Check environment variables
sudo systemctl cat chainforge
```

### High CPU Usage

```bash
# Check mining difficulty
grep DEFAULT_DIFFICULTY /var/www/chain_forge/.env

# Monitor active processes
top -u www-data

# Check for stuck mining operations
sudo journalctl -u chainforge | grep "mine_block"
```

### Database Issues

```bash
# Check MongoDB status
sudo systemctl status mongod

# Check disk space
df -h /var/lib/mongodb

# Repair database (if needed)
sudo systemctl stop mongod
mongod --repair
sudo systemctl start mongod
```

## Scaling Considerations

### Vertical Scaling

- Increase server resources (CPU, RAM)
- Use SSD for MongoDB data directory
- Optimize MongoDB queries with indexes

### Horizontal Scaling

**Not supported** - ChainForge is a single-instance application:
- No distributed consensus
- No peer-to-peer networking
- Rate limiting is memory-based

For production blockchain, consider:
- Ethereum
- Hyperledger Fabric
- Cosmos SDK

## Updates

### Application Updates

```bash
cd /var/www/chain_forge

# Backup first
sudo -u www-data mongodump ...

# Pull latest code
git fetch origin
git checkout v2.0.0  # or specific version

# Update dependencies
bundle install --deployment

# Restart application
sudo systemctl restart chainforge
```

### Security Updates

```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Ruby gems
bundle update --conservative

# Audit vulnerabilities
gem install bundler-audit
bundle audit check --update
```

## Maintenance

### Log Rotation

Create `/etc/logrotate.d/chainforge`:
```
/var/log/nginx/chainforge_*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

### Health Checks

```bash
# Check API health
curl https://api.yourdomain.com/

# Check MongoDB
mongo -u admin -p --authenticationDatabase admin --eval "db.adminCommand('ping')"

# Check disk space
df -h

# Check memory
free -h
```

## Support

For deployment issues:
- GitHub Issues: https://github.com/Perafan18/chain_forge/issues
- Documentation: README.md, SECURITY.md
