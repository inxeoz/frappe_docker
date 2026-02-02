# Docker to Setup (D2S) - Frappe Multi-Site Bench

Step-by-step guide to create and run multiple isolated Frappe sites using **Traefik reverse proxy**.

**Tested Architecture: `[Traefik :8100] → [Isolated Sites]` + Optional: `[Nginx :89] → [Traefik :8100]`**

## Quick Start Summary

**Core Setup (Always Works):**
1. Start ALIS site with Traefik: **5 minutes**
2. Start MAHAKAAL site: **2 minutes**  
3. Access via hostname headers: **Immediate**

**Optional nginx proxy:** For clean URLs (may need troubleshooting)

## 1. Prerequisites

- git
- Docker or Podman  
- Docker Compose v2
- nginx (optional - only for clean URLs on port 89)

## 2. Clone Repository

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

## 3. Verify Environment Files (Pre-configured)

The repository comes with pre-configured environment files:

```bash
# Check ALIS configuration
cat envs/alis.env | grep -E "(SITE_HOST|TRAEFIK_DOMAIN|HTTP_PUBLISH_PORT)"

# Check MAHAKAAL configuration  
cat envs/mahakaal.env | grep -E "(SITE_HOST|TRAEFIK_DOMAIN|HTTP_PUBLISH_PORT)"
```

Expected output:
- `SITE_HOST=s1.inxeoz.com` (ALIS)
- `SITE_HOST=s2.inxeoz.com` (MAHAKAAL)
- `TRAEFIK_DOMAIN=dashboard.localhost`
- `HTTP_PUBLISH_PORT=8100`

## 4. Verify Traefik Frontend Configurations

Check that routing configurations exist:

```bash
# Should show two YAML files
ls -la traefik_frontends/
cat traefik_frontends/traefik-alis.yaml | grep "Host("
cat traefik_frontends/traefik-mahakaal.yaml | grep "Host("
```

Expected output:
- `traefik-alis.yaml`: Host(`s1.inxeoz.com`)
- `traefik-mahakaal.yaml`: Host(`s2.inxeoz.com`)

## 5. Build Custom Image (If Needed)

> Checkout [Custom apps](02-setup/02-build-setup.md)

```bash
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --tag=custom:15 \
  --file=images/layered/Containerfile .
```

## 6. Start ALIS Site (with Traefik)

This starts Traefik + complete ALIS stack:

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

Verify containers are running:
```bash
docker ps | grep -E "(traefik|alis-)"
```

## 7. Start MAHAKAAL Site

This adds the second isolated site:

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

Verify all containers:
```bash
docker ps | grep -E "(traefik|alis-|mahakaal-)" | wc -l
# Should show ~19 containers
```

## 8. Create Frappe Sites

Create ALIS site:
```bash
docker compose -p alis exec backend bench new-site s1.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123
```

Create MAHAKAAL site:
```bash
docker compose -p mahakaal exec backend bench new-site s2.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123
```

## 9. Test Site Access

**Method 1: Direct Traefik Access (Always Works)**

```bash
# Test ALIS site
curl -H "Host: s1.inxeoz.com" http://localhost:8100 | grep -o "<title>[^<]*"

# Test MAHAKAAL site  
curl -H "Host: s2.inxeoz.com" http://localhost:8100 | grep -o "<title>[^<]*"

# Test Traefik dashboard
curl -H "Host: dashboard.localhost" http://localhost:8100
```

Expected output: `<title>Login` for both sites

**Method 2: Browser Access with DNS**

Add to `/etc/hosts`:
```bash
echo '127.0.0.1 s1.inxeoz.com' | sudo tee -a /etc/hosts
echo '127.0.0.1 s2.inxeoz.com' | sudo tee -a /etc/hosts  
echo '127.0.0.1 dashboard.localhost' | sudo tee -a /etc/hosts
```

Then access in browser:
- **ALIS**: `http://s1.inxeoz.com:8100`
- **MAHAKAAL**: `http://s2.inxeoz.com:8100`  
- **Traefik Dashboard**: `http://dashboard.localhost:8100`

---

## 🎉 Core Setup Complete!

At this point you have:
- ✅ **2 completely isolated Frappe sites**
- ✅ **Auto-discovery routing via Traefik**
- ✅ **Separate databases and Redis per site**
- ✅ **Working login pages for both sites**

The remaining sections are **optional enhancements**.

---

## Optional: nginx Proxy for Clean URLs

If you want URLs without port numbers (`http://s1.inxeoz.com:89`), set up nginx:

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

The architecture supports unlimited sites with **zero configuration changes**:

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

### 4. Create site and test
```bash
docker compose -p newsite exec backend bench new-site s3.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123

curl -H "Host: s3.inxeoz.com" http://localhost:8100
```

**Result**: `http://s3.inxeoz.com:8100` works immediately!

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