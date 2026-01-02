# Quick Start Deployment Guide

This is a condensed guide to get your app deployed quickly. For detailed information, see [DEPLOYMENT.md](./DEPLOYMENT.md).

## Prerequisites Checklist

- [ ] VPS from ukraine.com.ua with root access
- [ ] Domain name (optional but recommended)
- [ ] Docker Hub account
- [ ] GitHub repository
- [ ] Telegram bot token from @BotFather

## Step 1: Initial VPS Setup

SSH into your VPS and run:

```bash
# Copy setup script to VPS
scp setup-vps.sh root@your-vps-ip:/root/

# On VPS
ssh root@your-vps-ip
chmod +x setup-vps.sh
./setup-vps.sh
```

Or manually:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /opt/auto-market-intelligence
cd /opt/auto-market-intelligence

# Copy docker-compose.prod.yml
scp docker-compose.prod.yml root@your-vps-ip:/opt/auto-market-intelligence/

# Create Kamal network
docker network create kamal
```

## Step 2: Configure GitHub Secrets

Go to your GitHub repository → **Settings → Secrets and variables → Actions**

Add these secrets:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `DEPLOY_HOST` | VPS IP or domain | `123.45.67.89` or `app.example.com` |
| `DEPLOY_USER` | SSH user | `root` |
| `DEPLOY_DOMAIN` | Your domain | `bidly.tech` |
| `DEPLOY_SSH_KEY` | Private SSH key | Content of `~/.ssh/id_rsa` |
| `DOCKER_USERNAME` | Docker Hub username | `yourusername` |
| `DOCKER_PASSWORD` | Docker Hub token | Your Docker Hub access token |
| `RAILS_MASTER_KEY` | Rails master key | From `rails_api/config/master.key` |
| `DATABASE_URL` | PostgreSQL URL | `postgresql://car_bot:password@localhost:5432/car_bot_production` |
| `REDIS_URL` | Redis URL | `redis://localhost:6379/0` |
| `KAFKA_BROKERS` | Kafka brokers | `localhost:9092` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | From @BotFather |
| `POSTGRES_PASSWORD` | PostgreSQL password | Strong password |

### Generate SSH Key (if needed)

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# Copy private key content
cat ~/.ssh/id_rsa
```

### Get Rails Master Key

```bash
cd rails_api
cat config/master.key
# Or generate new credentials
EDITOR="nano" rails credentials:edit
```

## Step 3: Update Kamal Configuration

Edit `rails_api/config/deploy.yml`:

```yaml
servers:
  web:
    hosts:
      - your-vps-ip-or-domain  # Replace this
    options:
      user: root  # Or your SSH user

proxy:
  ssl: true
  host: your-domain.com  # Replace with your domain
```

## Step 4: Deploy!

### Option A: Automatic (Recommended)

Just push to GitHub:

```bash
git add .
git commit -m "feat: initial deployment setup"
git push origin main
```

GitHub Actions will automatically:
1. Build Docker images
2. Push to Docker Hub
3. Deploy Rails API with Kamal
4. Deploy Python workers
5. Deploy Telegram bot

### Option B: Manual Deployment

#### Deploy Rails API

```bash
cd rails_api

# Install Kamal
gem install kamal

# Set up secrets
mkdir -p .kamal
cat > .kamal/secrets <<EOF
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgresql://car_bot:password@localhost:5432/car_bot_production
REDIS_URL=redis://localhost:6379/0
KAFKA_BROKERS=localhost:9092
TELEGRAM_BOT_TOKEN=your_token
POSTGRES_PASSWORD=your_password
EOF

# Copy SSH key
cp ~/.ssh/id_rsa .kamal/id_rsa
chmod 600 .kamal/id_rsa

# Deploy
kamal setup  # First time only
kamal deploy
```

#### Deploy Other Services

On your VPS:

```bash
cd /opt/auto-market-intelligence

# Update .env file with your values
nano .env

# Pull and start services
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

## Step 5: Verify Deployment

```bash
# Check Rails API
curl https://your-domain.com/up

# Check services
ssh root@your-vps-ip
docker ps

# View logs
kamal app logs  # Rails API
docker logs car_bot_python_workers -f
docker logs car_bot_telegram -f
```

## Troubleshooting

### Can't connect to VPS
- Check firewall: `ufw status`
- Verify SSH key: `ssh -i ~/.ssh/id_rsa root@your-vps-ip`

### Services not starting
- Check logs: `docker logs <container_name>`
- Check network: `docker network ls`
- Verify .env file: `cat /opt/auto-market-intelligence/.env`

### Database connection errors
- Check database is running: `kamal accessory logs db`
- Verify DATABASE_URL in secrets

### SSL certificate issues
- Ensure domain points to VPS IP
- Check DNS: `dig your-domain.com`
- Kamal will auto-generate Let's Encrypt cert

## Next Steps

- Set up monitoring
- Configure backups
- Set up CI/CD for other branches
- Configure firewall rules
- Set up log rotation

For detailed information, see [DEPLOYMENT.md](./DEPLOYMENT.md).

