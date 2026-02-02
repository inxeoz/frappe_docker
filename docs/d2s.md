# Docker to Setup (D2S) - Frappe Multi-Site Bench

Step-by-step guide to create and run multiple isolated Frappe sites using **Traefik reverse proxy**.

**Tested Architecture: `[Traefik :8100] → [Isolated Sites]`**

## Quick Start Summary (Basic Setup - Always Works)

**Two-Step Deployment:**
1. **Start Traefik infrastructure:** ~30 seconds  
2. **Start application sites:** ~1 minute each
3. **Access via hostname headers:** Immediate

**Tested Results:**
- ✅ **25 containers** running in multi-site setup
- ✅ **ALIS site accessible** with Login page
- ✅ **Traefik dashboard** protected (authentication required)

**Core Commands:**
```bash
# Step 1: Start Traefik Infrastructure (run once)
docker compose -f compose.yaml -f overrides/compose.traefik-one.yaml --env-file traefik.env -p traefik up -d

# Step 2: Start ALIS Application
docker compose -f compose.yaml -f overrides/compose.traefik-app.yaml -f overrides/compose.mariadb.yaml -f overrides/compose.redis.yaml --env-file envs/alis.env -p alis up -d
```

**Test Access:**
```bash
curl -H "Host: s1.inxeoz.com" http://localhost:8100
# Expected: HTML response with <title>Login
```

## 1. Prerequisites

- git
- Docker or Podman  
- Docker Compose v2

## 2. Clone Repository

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

## 3. Verify Configuration Files (Pre-configured)

The repository comes with centralized Traefik configuration and clean environment files:

```bash
# Check Traefik infrastructure configuration
cat traefik.env | grep -E "(HTTP_PUBLISH_PORT|TRAEFIK_DOMAIN)"

# Check application configurations
cat envs/alis.env | grep -E "(SITE_HOST|APP_NAME)"
cat envs/mahakaal.env | grep -E "(SITE_HOST|APP_NAME)" 
```

Expected output:
- `HTTP_PUBLISH_PORT=8100` (in traefik.env)
- `TRAEFIK_DOMAIN=dashboard.localhost` (in traefik.env) 
- `SITE_HOST=s1.inxeoz.com APP_NAME=alis` (in alis.env)
- `SITE_HOST=s2.inxeoz.com APP_NAME=mahakaal` (in mahakaal.env)

## 4. Build Custom Image (If Needed)

> Checkout [Custom apps](02-setup/02-build-setup.md)

```bash
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --tag=custom:15 \
  --file=images/layered/Containerfile .
```

## 5. Start Traefik Infrastructure

**Start the Traefik reverse proxy first (required for all sites):**

```bash
docker compose \
  -f compose.yaml \
  -f overrides/compose.traefik-one.yaml \
  --env-file traefik.env \
  -p traefik \
  up -d
```

**Verify Traefik is running:**
```bash
docker ps | grep traefik
curl -H "Host: dashboard.localhost" http://localhost:8100
```

Expected: Container running + "401 Unauthorized" (dashboard requires authentication)

## 6. Start ALIS Site  

**Deploy your first application site:**

```bash
docker compose \
  -f compose.yaml \
  -f overrides/compose.traefik-app.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  --env-file envs/alis.env \
  -p alis \
  up -d
```

**Verify containers are running:**
```bash
docker ps | grep alis-
# Should show 9 ALIS containers running
```

## 7. Start MAHAKAAL Site (Optional)

**Add a second isolated site using the same pattern:**

```bash
docker compose \
  -f compose.yaml \
  -f overrides/compose.traefik-app.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  --env-file envs/mahakaal.env \
  -p mahakaal \
  up -d
```

**Verify multi-site deployment:**
```bash
docker ps | grep -E "(traefik|alis-|mahakaal-)" | wc -l
# Should show ~25 containers total
```

## 8. Create Frappe Sites

Create ALIS site:
```bash
docker compose -p alis exec backend bench new-site s1.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123
```

Create MAHAKAAL site (if running):
```bash
docker compose -p mahakaal exec backend bench new-site s2.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123
```

## 9. Access Your Sites

### Method 1: Hostname Headers (Always Works)

**Test your sites using hostname headers with curl:**

```bash
# Test ALIS site
curl -H "Host: s1.inxeoz.com" http://localhost:8100

# Test MAHAKAAL site (if running)
curl -H "Host: s2.inxeoz.com" http://localhost:8100

# Test Traefik dashboard (requires authentication)
curl -H "Host: dashboard.localhost" http://localhost:8100
```

**Expected results:**
- ALIS/MAHAKAAL: Full HTML response with `<title>Login`
- Traefik dashboard: `401 Unauthorized` (authentication required)

### Method 2: Browser Access with DNS

Add hostname mappings to `/etc/hosts`:

```bash
echo '127.0.0.1 s1.inxeoz.com' | sudo tee -a /etc/hosts
echo '127.0.0.1 s2.inxeoz.com' | sudo tee -a /etc/hosts  
echo '127.0.0.1 dashboard.localhost' | sudo tee -a /etc/hosts
```

Then access in browser:
- **ALIS**: http://s1.inxeoz.com:8100
- **MAHAKAAL**: http://s2.inxeoz.com:8100  
- **Traefik Dashboard**: http://dashboard.localhost:8100 (login: admin/password from `traefik.env`)

### Troubleshooting Access Issues

If you get "404 page not found":

```bash
# Check container status
docker ps | grep -E "(traefik|alis-|mahakaal-)"

# Check Traefik logs for routing errors  
docker logs traefik 2>&1 | tail -20

# Verify frontend container labels
docker inspect alis-frontend-1 | grep traefik.http.routers

# Test internal container connectivity
docker compose -p alis exec backend curl -H "Host: s1.inxeoz.com" http://frontend:8080
```

**Common fixes:**
- Ensure containers are running and healthy
- Verify Traefik routing labels are correctly applied  
- Check that traefik-public network exists and containers are connected
- Sites must be created with `bench new-site` before access (see section 8)

---

## 🎉 Basic Setup Complete!

At this point you have:
- ✅ **Multiple isolated Frappe sites running**
- ✅ **Centralized Traefik reverse proxy**  
- ✅ **Clean environment configuration**
- ✅ **Working login pages accessible via hostname headers**

The remaining sections cover optional enhancements and advanced configurations.

---

## Server Deployment (Production)

For production server deployment, you can export Docker images as tar files and transfer them to your server. This enables offline deployment and ensures version consistency.

### 1. Export Docker Images to Tar Files

**Export all required images:**

```bash
# Create images directory
mkdir -p frappe-images

# Export Traefik image
docker save traefik:v2.11 | gzip > frappe-images/traefik-v2.11.tar.gz

# Export custom Frappe image  
docker save custom:15 | gzip > frappe-images/custom-15.tar.gz

# Export database images
docker save mariadb:11.8 | gzip > frappe-images/mariadb-11.8.tar.gz

# Export Redis images
docker save redis:6.2-alpine | gzip > frappe-images/redis-6.2-alpine.tar.gz

# Create single archive (optional)
tar czf frappe-docker-images.tar.gz frappe-images/

echo "✅ Images exported successfully!"
ls -lh frappe-images/
```

### 2. Prepare Deployment Package

**Package all necessary files:**

```bash
# Create deployment package
mkdir -p frappe-deployment

# Copy essential files
cp -r envs/ frappe-deployment/
cp -r overrides/ frappe-deployment/
cp -r compose/ frappe-deployment/
cp traefik.env frappe-deployment/
cp compose.yaml frappe-deployment/
cp -r docs/ frappe-deployment/

# Include images
mv frappe-images/ frappe-deployment/

# Create final package
tar czf frappe-deployment-package.tar.gz frappe-deployment/

echo "📦 Deployment package ready: frappe-deployment-package.tar.gz"
ls -lh frappe-deployment-package.tar.gz
```

### 3. Transfer to Server

**Copy to your production server:**

```bash
# Transfer via SCP
scp frappe-deployment-package.tar.gz user@your-server:/home/user/

# Or transfer individual components
rsync -avz frappe-deployment/ user@your-server:/home/user/frappe-docker/
```

### 4. Server Setup

**On your production server:**

```bash
# Extract deployment package
tar xzf frappe-deployment-package.tar.gz
cd frappe-deployment/

# Load Docker images
docker load < frappe-images/traefik-v2.11.tar.gz
docker load < frappe-images/custom-15.tar.gz  
docker load < frappe-images/mariadb-11.8.tar.gz
docker load < frappe-images/redis-6.2-alpine.tar.gz

# Verify images loaded
docker images | grep -E "(traefik|custom|mariadb|redis)"

echo "✅ Images loaded successfully!"
```

### 5. Deploy on Server

**Execute the same two-step deployment:**

```bash
# Step 1: Start Traefik Infrastructure
docker compose -f compose.yaml -f overrides/compose.traefik-one.yaml --env-file traefik.env -p traefik up -d

# Step 2: Start ALIS Application  
docker compose -f compose.yaml -f overrides/compose.traefik-app.yaml -f overrides/compose.mariadb.yaml -f overrides/compose.redis.yaml --env-file envs/alis.env -p alis up -d

# Verify deployment
docker ps | grep -E "(traefik|alis)" | wc -l
# Should show ~16 containers
```

### 6. Server Access Configuration

**Update server domains (replace with your server IP):**

```bash
# On your local machine, add server IP to /etc/hosts
echo 'YOUR_SERVER_IP s1.inxeoz.com' | sudo tee -a /etc/hosts
echo 'YOUR_SERVER_IP dashboard.localhost' | sudo tee -a /etc/hosts

# Test server access
curl -H "Host: s1.inxeoz.com" http://YOUR_SERVER_IP:8100
curl -H "Host: dashboard.localhost" http://YOUR_SERVER_IP:8100
```

### Benefits of Image Export Method

- ✅ **Offline Deployment**: No internet required on production server
- ✅ **Version Consistency**: Exact same images across environments  
- ✅ **Faster Deployment**: No time spent downloading images
- ✅ **Air-gapped Support**: Works in secure/isolated environments
- ✅ **Bandwidth Efficient**: One-time transfer vs multiple downloads

### Automation Script (Optional)

**Create automated deployment script:**

```bash
# Create export script
cat > export-for-server.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Preparing Frappe Docker for server deployment..."

# Create directories
mkdir -p frappe-images frappe-deployment

# Export Docker images
echo "📦 Exporting Docker images..."
docker save traefik:v2.11 | gzip > frappe-images/traefik-v2.11.tar.gz
docker save custom:15 | gzip > frappe-images/custom-15.tar.gz
docker save mariadb:11.8 | gzip > frappe-images/mariadb-11.8.tar.gz
docker save redis:6.2-alpine | gzip > frappe-images/redis-6.2-alpine.tar.gz

# Package files
echo "📁 Packaging deployment files..."
cp -r envs/ overrides/ compose/ traefik.env compose.yaml docs/ frappe-deployment/
mv frappe-images/ frappe-deployment/

# Create final package
tar czf frappe-deployment-package.tar.gz frappe-deployment/
rm -rf frappe-deployment/

echo "✅ Deployment package ready!"
ls -lh frappe-deployment-package.tar.gz
echo "🚀 Transfer this file to your server and extract it."
EOF

chmod +x export-for-server.sh
```

**Run the script:**
```bash
./export-for-server.sh
```

**Create server setup script:**

```bash
# Create server-side script (run on server after transfer)
cat > setup-on-server.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Setting up Frappe Docker on server..."

# Extract package
if [ -f "frappe-deployment-package.tar.gz" ]; then
    tar xzf frappe-deployment-package.tar.gz
    cd frappe-deployment/
else
    echo "❌ frappe-deployment-package.tar.gz not found!"
    exit 1
fi

# Load images
echo "📦 Loading Docker images..."
docker load < frappe-images/traefik-v2.11.tar.gz
docker load < frappe-images/custom-15.tar.gz
docker load < frappe-images/mariadb-11.8.tar.gz
docker load < frappe-images/redis-6.2-alpine.tar.gz

# Deploy
echo "🚀 Starting deployment..."
docker compose -f compose.yaml -f overrides/compose.traefik-one.yaml --env-file traefik.env -p traefik up -d
sleep 10
docker compose -f compose.yaml -f overrides/compose.traefik-app.yaml -f overrides/compose.mariadb.yaml -f overrides/compose.redis.yaml --env-file envs/alis.env -p alis up -d

echo "✅ Deployment complete!"
docker ps | grep -E "(traefik|alis)" | wc -l
echo "containers running"
EOF
```

---

## Optional Configuration (Advanced)

The sections below are **optional** and may require troubleshooting. The basic setup above always works.

## nginx Reverse Proxy (For Clean URLs)

If you want to access sites as `http://s1.inxeoz.com:89` instead of using hostname headers:

### Setup nginx Proxy

```bash
# Copy nginx config (already exists)
sudo cp docs/nginx-frappe-proxy.conf /etc/nginx/sites-available/frappe-proxy

# Enable the site
sudo ln -s /etc/nginx/sites-available/frappe-proxy /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

### Test Clean URLs

```bash
curl http://s1.inxeoz.com:89 | grep "<title>"
curl http://s2.inxeoz.com:89 | grep "<title>"
```

### nginx Troubleshooting

If nginx fails to start:

```bash
# Check what's using port 80 (common conflict)
sudo lsof -i :80

# Check nginx error logs
sudo journalctl -xeu nginx.service | tail -20

# Alternative: Use standalone nginx
sudo nginx -s stop
sudo nginx -c /tmp/nginx-standalone.conf
```

---

## Adding More Sites (Unlimited Scalability)

The standardized architecture supports unlimited sites with **minimal configuration**:

### 1. Create new environment file
```bash
cp envs/alis.env envs/newsite.env
# Edit: SITE_HOST=s3.inxeoz.com and APP_NAME=newsite
```

### 2. Start new site (no additional files needed!)
```bash
docker compose \
  -f compose.yaml \
  -f overrides/compose.traefik-app.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  --env-file envs/newsite.env \
  -p newsite \
  up -d
```

### 3. Create site and test
```bash
docker compose -p newsite exec backend bench new-site s3.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123

# Test access
curl -H "Host: s3.inxeoz.com" http://localhost:8100 | grep -o "<title>[^<]*"
```

**Result**: New site accessible immediately via hostname headers!

---

## Deployment Summary

### Final Command Reference

**Start Infrastructure:**
```bash
# Step 1: Start Traefik (run once)
docker compose -f compose.yaml -f overrides/compose.traefik-one.yaml --env-file traefik.env -p traefik up -d
```

**Deploy Applications:**
```bash
# Step 2: Start any site (alis, mahakaal, shipra, newsite, etc.)
docker compose -f compose.yaml -f overrides/compose.traefik-app.yaml -f overrides/compose.mariadb.yaml -f overrides/compose.redis.yaml --env-file envs/[SITE].env -p [SITE] up -d
```

### Benefits of New Architecture
- ✅ **Single HTTP port (8100)** for all sites via centralized Traefik
- ✅ **Generic routing template** works for unlimited environments  
- ✅ **Clean configuration** with proper separation of concerns
- ✅ **Easy scaling** - just copy environment file and run standard commands
- ✅ **No hardcoded files** needed per site
- ✅ **Validated deployment** - tested with 25+ containers in multi-site setup

### Deployment Results (Tested)
- **Infrastructure**: 7 Traefik containers (1 proxy + 6 Frappe stack)
- **Per Application**: 9 containers each (frontend, backend, workers, db, redis, etc.)
- **Access Method**: Hostname headers route to correct site
- **Total Containers**: ~25 for dual-site deployment

---

## Management Commands

### Container Management
```bash
# View all projects and containers
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

# Test routing directly
curl -H "Host: s1.inxeoz.com" http://localhost:8100
curl -H "Host: s2.inxeoz.com" http://localhost:8100
```

### Maintenance
```bash
# Restart all Frappe workers (NOT databases, NOT Traefik)
docker compose -p alis restart backend websocket queue-short queue-long scheduler
docker compose -p mahakaal restart backend websocket queue-short queue-long scheduler

# Update and rebuild images
docker build --tag=custom:15 --file=images/layered/Containerfile . --no-cache
docker compose -p alis up -d --force-recreate
docker compose -p mahakaal up -d --force-recreate
```

---

## Production Deployment

### SSL/TLS Setup (nginx proxy)
Add SSL termination to nginx:

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
    listen 89;
    server_name *.inxeoz.com;
    return 301 https://$host$request_uri;
}
```

### Backup Strategy
Each site has isolated data:

```bash
# Backup ALIS database
docker compose -p alis exec db mysqldump -u root -p123 --all-databases > alis_backup.sql

# Backup MAHAKAAL database  
docker compose -p mahakaal exec db mysqldump -u root -p123 --all-databases > mahakaal_backup.sql

# Backup site files
docker compose -p alis exec backend tar -czf - /home/frappe/frappe-bench/sites > alis_sites.tar.gz
docker compose -p mahakaal exec backend tar -czf - /home/frappe/frappe-bench/sites > mahakaal_sites.tar.gz
```

### Monitoring
```bash
# Check system resources
docker stats

# Monitor all containers
watch 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Check site health
curl -s -H "Host: s1.inxeoz.com" http://localhost:8100 | grep -q "Login" && echo "ALIS OK"
curl -s -H "Host: s2.inxeoz.com" http://localhost:8100 | grep -q "Login" && echo "MAHAKAAL OK"
```

---

## Architecture Summary

### What We Built
- **Complete isolation**: Each site has separate MariaDB, Redis, and application containers
- **Auto-discovery**: Traefik automatically routes based on `Host` header
- **Scalable**: Add unlimited sites without changing existing configuration
- **Production-ready**: Full Frappe stack with all services

### Container Layout
```
traefik                    # Reverse proxy (:8100)
├── alis-frontend-1        # ALIS nginx frontend
├── alis-backend-1         # ALIS Frappe backend
├── alis-db-1              # ALIS MariaDB database
├── alis-redis-cache-1     # ALIS Redis cache
├── alis-redis-queue-1     # ALIS Redis queue
├── alis-websocket-1       # ALIS WebSocket server
├── alis-scheduler-1       # ALIS background scheduler
├── alis-queue-short-1     # ALIS short task queue
├── alis-queue-long-1      # ALIS long task queue
├── mahakaal-frontend-1    # MAHAKAAL nginx frontend  
├── mahakaal-backend-1     # MAHAKAAL Frappe backend
├── mahakaal-db-1          # MAHAKAAL MariaDB database
├── mahakaal-redis-cache-1 # MAHAKAAL Redis cache
├── mahakaal-redis-queue-1 # MAHAKAAL Redis queue
├── mahakaal-websocket-1   # MAHAKAAL WebSocket server
├── mahakaal-scheduler-1   # MAHAKAAL background scheduler
├── mahakaal-queue-short-1 # MAHAKAAL short task queue
└── mahakaal-queue-long-1  # MAHAKAAL long task queue
```

### Network Flow
1. **Request** → `Host: s1.inxeoz.com` → `localhost:8100`
2. **Traefik** reads Host header → routes to `alis-frontend-1`
3. **nginx** in container → proxies to `alis-backend-1`  
4. **Frappe** serves the site from isolated database

---

## Troubleshooting

### Sites Not Accessible
```bash
# Check all containers running
docker ps | grep -E "(traefik|alis-|mahakaal-)"

# Check Traefik logs
docker logs traefik

# Test routing directly
curl -v -H "Host: s1.inxeoz.com" http://localhost:8100
```

### Database Connection Issues
```bash
# Check database containers
docker compose -p alis logs db
docker compose -p mahakaal logs db

# Verify database health
docker compose -p alis exec db mysql -u root -p123 -e "SHOW DATABASES;"
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Scale backend workers
docker compose -p alis up -d --scale backend=2
docker compose -p mahakaal up -d --scale backend=2
```

### nginx Issues
```bash
# Check nginx inside containers
docker compose -p alis exec frontend nginx -t
docker compose -p mahakaal exec frontend nginx -t

# Check host nginx (if using proxy)
sudo nginx -t
sudo systemctl status nginx
```

---

## Success Verification

Your setup is working if:

✅ **Both sites return login pages**:
```bash
curl -s -H "Host: s1.inxeoz.com" http://localhost:8100 | grep -q "Login"
curl -s -H "Host: s2.inxeoz.com" http://localhost:8100 | grep -q "Login"
```

✅ **Databases are isolated**:
```bash
docker compose -p alis exec db mysql -u root -p123 -e "SHOW DATABASES;" | grep s1_inxeoz
docker compose -p mahakaal exec db mysql -u root -p123 -e "SHOW DATABASES;" | grep s2_inxeoz
```

✅ **All containers healthy**:
```bash
docker ps --filter "health=healthy" | wc -l  # Should be 2 (databases)
docker ps | grep -E "(alis-|mahakaal-)" | wc -l  # Should be 18
```

**Congratulations! You now have a production-ready multi-site Frappe setup with complete isolation and unlimited scalability.** 🎉