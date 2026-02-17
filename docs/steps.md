Docker to Setup (D2S) - Frappe Multi-Site Bench

## 1. Prerequisites

- git
- Docker or Podman  
- Docker Compose v2

## 2. Clone Repository

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```


## 3. Define custom apps

If you dont want to install specific apps to the image skip this section.

To include custom apps in your image, create an `apps.json` file in the repository root:

```json
[
  {
    "url": "https://github.com/frappe/erpnext",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/hrms",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/username/yourcustomapp",
    "branch": "appbranch"
  }
]
```

Then generate a base64-encoded string from this file:

```bash
export APPS_JSON_BASE64=$(base64 -w 0 apps.json)
```

## 4. Build Custom Image

```bash
docker build \
 --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
 --build-arg=FRAPPE_BRANCH=version-15 \
 --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
 --tag=custom:15 \
 --file=images/layered/Containerfile .
```
skip `` --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \`` if not neede custom apps

## 5. Start Traefik Infrastructure

**Start the Traefik reverse proxy first (required for all sites):**

traefik.env
```text

# Port on host where Traefik listens
HTTP_PUBLISH_PORT=80

# Domain used to access Traefik dashboard
TRAEFIK_DOMAIN=traefik.local

# Hashed password for dashboard login (bcrypt format)
HASHED_PASSWORD=$2a$12$REPLACE_WITH_REAL_HASH
```

```bash
docker compose \
  -f overrides/compose.traefik-one.yaml \
  --env-file traefik.env \
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


## 8. Create Frappe Sites

Create ALIS site:
```bash
docker compose -p alis exec backend bench new-site s1.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin123
```
``--install-app appname`` if app is embedded

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
