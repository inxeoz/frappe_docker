# Docker to Setup (D2S) - Frappe Multi-Site Bench

Step-by-step guide to create and run multiple isolated Frappe sites with hybrid proxy setup.

**Architecture: `[Host Nginx :80] → [Traefik :8100] → [Unlimited Sites]`**

## 1. Prerequisites

- git
- Docker or Podman  
- Docker Compose v2
- nginx (installed on host system)
- Root access (for nginx configuration)

## 2. Clone Repository

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

## 3. Setup Host Nginx Proxy

Configure nginx to proxy all `*.inxeoz.com` requests to Traefik:

```bash
# Copy nginx configuration
sudo cp docs/nginx-frappe-proxy.conf /etc/nginx/sites-available/frappe-proxy

# Enable the site
sudo ln -s /etc/nginx/sites-available/frappe-proxy /etc/nginx/sites-enabled/

# Test and reload nginx
sudo nginx -t && sudo systemctl reload nginx
```

## 4. Setup DNS Resolution

Add domains to `/etc/hosts` for local development:

```bash
# Add these entries to /etc/hosts
127.0.0.1 s1.inxeoz.com
127.0.0.1 s2.inxeoz.com
127.0.0.1 dashboard.localhost
```

## 5. Prepare Environment Files

Create environment files for each site:

```bash
# ALIS site (s1.inxeoz.com)
cp example.env envs/alis.env
```

Edit `envs/alis.env`:
```txt
DB_PASSWORD=your_secure_password
CUSTOM_IMAGE=custom
CUSTOM_TAG=15
PULL_POLICY=missing
SITE_HOST=s1.inxeoz.com
TRAEFIK_DOMAIN=dashboard.localhost
HASHED_PASSWORD='$2a$12$8htSjwtTDj8qm6P7d0LsfuUg/d0l39L/6m7mYNdO2vu6e9aY.rcfW'
```

```bash
# MAHAKAAL site (s2.inxeoz.com)  
cp envs/alis.env envs/mahakaal.env
```

Edit `envs/mahakaal.env`:
```txt
SITE_HOST=s2.inxeoz.com
# Keep other settings same
```

## 6. Build Custom Image

> Checkout [Custom apps](02-setup/02-build-setup.md)

```bash
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --tag=custom:15 \
  --file=images/layered/Containerfile .
```

## 7. Start ALIS Site (with Traefik)

```bash
docker compose \
  -f compose.yaml \
  -f overrides/compose.traefik-one.yaml \
  -f traefik_frontends/traefik-alis.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  --env-file envs/alis.env \
  -p alis \
  up -d
```

## 8. Start MAHAKAAL Site

```bash
docker compose \
  -f compose.yaml \
  -f traefik_frontends/traefik-mahakaal.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  --env-file envs/mahakaal.env \
  -p mahakaal \
  up -d
```

## 9. Create Sites

Create ALIS site:
```bash
docker compose -p alis exec backend bench new-site s1.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --admin-password your_admin_password
```

Create MAHAKAAL site:
```bash
docker compose -p mahakaal exec backend bench new-site s2.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --admin-password your_admin_password
```

## 10. Access Sites

**Clean URLs via hybrid proxy setup:**

- 🌐 **ALIS Site**: `http://s1.inxeoz.com` 
- 🌐 **MAHAKAAL Site**: `http://s2.inxeoz.com`
- 📊 **Traefik Dashboard**: `http://dashboard.localhost:8100`

**Test connectivity:**
```bash
# Test ALIS site
curl -I http://s1.inxeoz.com

# Test MAHAKAAL site  
curl -I http://s2.inxeoz.com

# Direct Traefik test
curl -H "Host: s1.inxeoz.com" http://localhost:8100
```

---

## Adding More Sites (Zero Nginx Config Changes!)

The hybrid architecture allows unlimited scalability:

### 1. Create new environment file
```bash
cp envs/alis.env envs/newsite.env
# Edit SITE_HOST=s3.inxeoz.com
```

### 2. Create Traefik routing
Create `traefik_frontends/traefik-newsite.yaml`:
```yaml
services:
  frontend:
    networks:
      - traefik-public
      - default
    labels:
      traefik.enable: "true"
      traefik.docker.network: "traefik-public"
      traefik.http.routers.newsite-frontend.rule: "Host(`s3.inxeoz.com`)"
      traefik.http.routers.newsite-frontend.entrypoints: "web"
      traefik.http.services.newsite-frontend.loadbalancer.server.port: "8080"

networks:
  traefik-public:
    external: true
```

### 3. Start new site
```bash
docker compose \
  -f compose.yaml \
  -f traefik_frontends/traefik-newsite.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  --env-file envs/newsite.env \
  -p newsite \
  up -d
```

### 4. Add to hosts file
```bash
echo "127.0.0.1 s3.inxeoz.com" | sudo tee -a /etc/hosts
```

**Result**: `http://s3.inxeoz.com` works immediately!

---

## Management Commands

### Container Management
```bash
# View all running projects
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# Stop specific site
docker compose -p alis down
docker compose -p mahakaal down

# Restart services for specific site
docker compose -p alis restart frontend backend
docker compose -p mahakaal restart frontend backend

# Scale services
docker compose -p alis up -d --scale backend=2
docker compose -p mahakaal up -d --scale backend=3
```

### Logs and Debugging
```bash
# View logs for specific site
docker compose -p alis logs -f frontend
docker compose -p mahakaal logs -f backend

# Check Traefik routing
docker compose -p alis logs -f traefik

# Test Traefik directly
curl -H "Host: s1.inxeoz.com" http://localhost:8100
curl -H "Host: s2.inxeoz.com" http://localhost:8100
```

### Maintenance
```bash
# Restart all Frappe application workers (NOT databases, NOT nginx, NOT Traefik)
docker compose -p alis restart backend websocket queue-short queue-long scheduler
docker compose -p mahakaal restart backend websocket queue-short queue-long scheduler

# Update and rebuild images
docker build --tag=custom:15 --file=images/layered/Containerfile . --no-cache
docker compose -p alis up -d --force-recreate
docker compose -p mahakaal up -d --force-recreate
```

---

## Production Deployment

### SSL/TLS Setup
Add SSL termination to the nginx configuration:

```nginx
# Add to /etc/nginx/sites-available/frappe-proxy
server {
    listen 443 ssl http2;
    server_name *.inxeoz.com;
    
    # SSL certificates (use certbot for Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/inxeoz.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/inxeoz.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8100;
        # ... same proxy settings as HTTP
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name *.inxeoz.com;
    return 301 https://$host$request_uri;
}
```

### Backup Strategy
Each site has isolated data - backup independently:

```bash
# Backup ALIS site database
docker compose -p alis exec db mysqldump -u root -p --all-databases > alis_backup.sql

# Backup MAHAKAAL site database  
docker compose -p mahakaal exec db mysqldump -u root -p --all-databases > mahakaal_backup.sql

# Backup site files
docker compose -p alis exec backend tar -czf - /home/frappe/frappe-bench/sites > alis_sites.tar.gz
docker compose -p mahakaal exec backend tar -czf - /home/frappe/frappe-bench/sites > mahakaal_sites.tar.gz
```

### Monitoring
```bash
# Check system resources
docker stats

# Monitor nginx access logs
sudo tail -f /var/log/nginx/access.log

# Monitor specific site containers
docker compose -p alis top
docker compose -p mahakaal top
```

---

## Offline Server Setup

Deploy on a server without internet access:

### On Machine with Internet

1. **Save all required images:**
```bash
docker save -o frappe-images.tar \
  custom:15 \
  mariadb:11.8 \
  redis:6.2-alpine \
  traefik:v2.11
```

2. **Transfer to server:**
```bash
scp frappe-images.tar envs/ traefik_frontends/ docs/nginx-frappe-proxy.conf user@server:/home/user/frappe/
scp -r overrides/ user@server:/home/user/frappe/
```

### On Offline Server

1. **Install Docker and nginx** (via offline packages)

2. **Load images:**
```bash
docker load -i frappe-images.tar
```

3. **Setup nginx proxy:**
```bash
sudo cp nginx-frappe-proxy.conf /etc/nginx/sites-available/frappe-proxy
sudo ln -s /etc/nginx/sites-available/frappe-proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

4. **Follow steps 8-11** to start sites

---

## Troubleshooting

### Common Issues

**Sites not accessible:**
```bash
# Check nginx is running and configured
sudo nginx -t
sudo systemctl status nginx

# Check Traefik is running
docker compose -p alis ps traefik

# Test direct connection
curl -H "Host: s1.inxeoz.com" http://localhost:8100
```

**Database connection issues:**
```bash
# Check database containers
docker compose -p alis ps db
docker compose -p mahakaal ps db

# Check database logs
docker compose -p alis logs db
```

**Memory/Resource issues:**
```bash
# Check container resources
docker stats

# Restart specific services
docker compose -p alis restart backend
```

### Architecture Verification
```bash
# Verify the flow: nginx → traefik → services
curl -v http://s1.inxeoz.com 2>&1 | grep -E "(Host:|X-Forwarded)"
``` 

---

## Offline Server Setup

Deploy on a server connected via SSH without internet access.

### On Machine with Internet

1. **Check running images:**

```bash
docker compose -p frappe -f compose.custom.yaml ps
```

| Service | Image |
|---------|-------|
| backend, frontend, etc. | custom:15 |
| db | mariadb:11.8 |
| redis-cache, redis-queue | redis:6.2-alpine |

2. **Save images:**

```bash
docker save -o frappe-images.tar \
  custom:15 \
  mariadb:11.8 \
  redis:6.2-alpine \
  traefik:v2.11

```

2. **Transfer to server:**

```bash
scp frappe-images.tar custom.env compose.custom.yaml user@server:/home/user/frappe/
scp -r overrides/ user@server:/home/user/frappe/
```

### On Offline Server

1. **Install Docker** (via offline package if needed)

2. **Load images:**

```bash
docker load -i frappe-images.tar
```
3. Follow Steps from D2S [6](#6-start-containers)


### COMMON COMMAND

Restart **all Frappe application workers**
⚠️ **NOT databases, NOT nginx, NOT Traefik**

```bash
docker compose -p frappe restart \
  backend websocket queue-short queue-long scheduler
```
