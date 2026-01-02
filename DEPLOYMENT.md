# Deployment Guide for VPS (ukraine.com.ua)

This guide explains how to deploy the Auto Market Intelligence application to a VPS server from GitHub.

## Prerequisites

1. **VPS Server** from ukraine.com.ua with:
   - Ubuntu 20.04+ or similar Linux distribution
   - Root or sudo access
   - At least 4GB RAM (8GB+ recommended)
   - Docker and Docker Compose installed

2. **GitHub Repository** with:
   - Code pushed to `main` or `master` branch
   - GitHub Actions enabled

3. **Domain Name** (optional but recommended for SSL)

## Initial VPS Setup

### 1. Connect to Your VPS

```bash
ssh root@your-vps-ip
```

### 2. Run Initial Setup Script

Copy the `deploy.sh` script to your VPS and run it:

```bash
# On your local machine
scp deploy.sh root@your-vps-ip:/root/

# On VPS
ssh root@your-vps-ip
chmod +x deploy.sh
./deploy.sh
```

Or manually install Docker and Docker Compose:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 3. Create Application Directory

```bash
mkdir -p /opt/auto-market-intelligence
cd /opt/auto-market-intelligence
```

## GitHub Secrets Configuration

Configure the following secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets

1. **DEPLOY_HOST** - Your VPS IP address or domain (e.g., `123.45.67.89` or `app.example.com`)
2. **DEPLOY_USER** - SSH user (usually `root`)
3. **DEPLOY_DOMAIN** - Your domain name (e.g., `app.example.com`)
4. **DEPLOY_SSH_KEY** - Your private SSH key for VPS access
   ```bash
   # Generate if you don't have one
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   # Copy private key content
   cat ~/.ssh/id_rsa
   ```

5. **DOCKER_USERNAME** - Your Docker Hub username
6. **DOCKER_PASSWORD** - Your Docker Hub access token or password

### Application Secrets

7. **RAILS_MASTER_KEY** - Rails master key (from `rails_api/config/master.key` or generate new)
   ```bash
   cd rails_api
   EDITOR="nano" rails credentials:edit
   # Or copy from existing master.key file
   ```

8. **DATABASE_URL** - PostgreSQL connection string
   ```
   postgresql://car_bot:your_password@localhost:5432/car_bot_production
   ```

9. **REDIS_URL** - Redis connection string
   ```
   redis://localhost:6379/0
   ```

10. **KAFKA_BROKERS** - Kafka broker address
    ```
    localhost:9092
    ```

11. **TELEGRAM_BOT_TOKEN** - Your Telegram bot token from @BotFather

12. **POSTGRES_PASSWORD** - PostgreSQL database password

## Local Setup for Kamal Deployment

### 1. Install Kamal

```bash
gem install kamal
```

Or add to your Gemfile:

```ruby
gem "kamal", require: false
```

### 2. Configure Kamal

Edit `rails_api/config/deploy.yml` and update:

- `DEPLOY_HOST` - Your VPS IP or domain
- `DEPLOY_DOMAIN` - Your domain name
- `DEPLOY_USER` - SSH user (usually `root`)

### 3. Set Up Secrets

Create `.kamal/secrets` file in `rails_api/` directory:

```bash
cd rails_api
mkdir -p .kamal
cat > .kamal/secrets <<EOF
RAILS_MASTER_KEY=your_master_key_here
DATABASE_URL=postgresql://car_bot:password@localhost:5432/car_bot_production
REDIS_URL=redis://localhost:6379/0
KAFKA_BROKERS=localhost:9092
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
POSTGRES_PASSWORD=your_postgres_password
EOF
chmod 600 .kamal/secrets
```

### 4. Set Up SSH Key

```bash
# Copy your SSH private key to .kamal directory
cp ~/.ssh/id_rsa rails_api/.kamal/id_rsa
chmod 600 rails_api/.kamal/id_rsa
```

## Deployment Process

### Option 1: Automatic Deployment via GitHub Actions (Recommended)

1. Push your code to the `main` or `master` branch:
   ```bash
   git push origin main
   ```

2. GitHub Actions will automatically:
   - Build Docker images
   - Push to Docker Hub
   - Deploy Rails API using Kamal
   - Deploy Python workers
   - Deploy Telegram bot

### Option 2: Manual Deployment

#### Deploy Rails API with Kamal

```bash
cd rails_api

# First time setup (creates database, starts services)
kamal setup

# Regular deployment
kamal deploy
```

#### Deploy Other Services

```bash
# On your VPS
cd /opt/auto-market-intelligence

# Pull latest images
docker-compose -f docker-compose.prod.yml pull

# Start/restart services
docker-compose -f docker-compose.prod.yml up -d
```

## Post-Deployment

### 1. Verify Services

```bash
# Check Rails API
kamal app logs

# Check all services
docker ps

# Check service health
curl https://your-domain.com/up
```

### 2. Run Database Migrations

```bash
kamal app exec "bin/rails db:migrate"
```

### 3. Set Up SSL Certificate

Kamal will automatically set up Let's Encrypt SSL if you've configured the domain. If you need to manually set up SSL:

```bash
# Install certbot
apt-get update
apt-get install certbot

# Generate certificate
certbot certonly --standalone -d your-domain.com
```

## Monitoring and Maintenance

### View Logs

```bash
# Rails API logs
kamal app logs

# Python workers logs
docker logs car_bot_python_workers -f

# Telegram bot logs
docker logs car_bot_telegram -f

# All services
docker-compose -f docker-compose.prod.yml logs -f
```

### Restart Services

```bash
# Restart Rails API
kamal app restart

# Restart other services
docker-compose -f docker-compose.prod.yml restart
```

### Update Application

Simply push to GitHub and the CI/CD pipeline will handle the deployment:

```bash
git add .
git commit -m "feat: update application"
git push origin main
```

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ssh -i ~/.ssh/id_rsa root@your-vps-ip

# Test Docker connection
docker -H ssh://root@your-vps-ip ps
```

### Database Connection Issues

```bash
# Check database is running
kamal accessory logs db

# Test connection
kamal app exec "bin/rails dbconsole"
```

### Service Not Starting

```bash
# Check service status
docker ps -a

# Check logs
docker logs <container_name>

# Restart service
docker restart <container_name>
```

### SSL Certificate Issues

```bash
# Check certificate status
certbot certificates

# Renew certificate
certbot renew
```

## Environment Variables

Update environment variables in:

1. **GitHub Secrets** - For CI/CD pipeline
2. **`.kamal/secrets`** - For Kamal deployment
3. **`/opt/auto-market-intelligence/.env`** - For Docker Compose services

## Backup

### Database Backup

```bash
# Create backup
kamal accessory exec db "pg_dump -U car_bot car_bot_production" > backup.sql

# Restore backup
kamal accessory exec db "psql -U car_bot car_bot_production" < backup.sql
```

### Volume Backups

```bash
# Backup volumes
docker run --rm -v rails_api_storage:/data -v $(pwd):/backup alpine tar czf /backup/storage-backup.tar.gz /data
```

## Security Considerations

1. **Firewall**: Configure UFW or iptables to only allow necessary ports
   ```bash
   ufw allow 22/tcp   # SSH
   ufw allow 80/tcp   # HTTP
   ufw allow 443/tcp  # HTTPS
   ufw enable
   ```

2. **SSH Keys**: Use SSH keys instead of passwords
3. **Secrets**: Never commit secrets to Git
4. **Updates**: Keep system and Docker images updated
5. **Monitoring**: Set up monitoring and alerts

## Support

For issues with:
- **VPS Hosting**: Contact ukraine.com.ua support
- **Deployment**: Check GitHub Actions logs
- **Application**: Check application logs

## Additional Resources

- [Kamal Documentation](https://kamal-deploy.org/)
- [Docker Documentation](https://docs.docker.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

