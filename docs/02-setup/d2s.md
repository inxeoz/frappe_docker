# Docker to Setup (D2S) - Frappe Bench

Step-by-step guide to create and run a Frappe bench.

## 1. Prerequisites

- git
- Docker or Podman
- Docker Compose v2

## 2. Clone Repository

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
```

## 3. Create Environment File

```bash
cp example.env custom.env
```

Edit `custom.env` and set:

```txt
DB_PASSWORD=your_secure_password
CUSTOM_IMAGE=custom
CUSTOM_TAG=15
PULL_POLICY=missing
```

## 4. Build Image

```bash
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --tag=custom:15 \
  --file=images/layered/Containerfile .
```

## 5. Create Compose File

```bash
docker compose --env-file custom.env -p frappe \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  config > compose.custom.yaml
```

## 6. Start Containers

```bash
docker compose -p frappe -f compose.custom.yaml up -d
```

## 7. Create Site

```bash
docker compose -p frappe exec backend bench new-site <sitename> \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --install-app erpnext \
  --admin-password your_admin_password
```

## 8. Access Site

Open browser: `http://localhost:8080`

---

## Overrides

Use overrides to customize your setup for different use cases.

```bash
docker compose --env-file custom.env -p frappe \
  -f compose.yaml \
  -f overrides/compose.<override1>.yaml \
  -f overrides/compose.<override2>.yaml \
  config > compose.custom.yaml
```

| Override | Purpose | Notes |
|----------|---------|-------|
| **Database** | | |
| compose.mariadb.yaml | Add MariaDB container | Default database |
| compose.mariadb-shared.yaml | MariaDB on shared network | For multi-bench setups |
| compose.mariadb-secrets.yaml | MariaDB with secrets file | Set `DB_PASSWORD_SECRETS_FILE` |
| compose.postgres.yaml | Use PostgreSQL instead | |
| **Redis** | | |
| compose.redis.yaml | Add Redis for cache/queue | |
| **Proxy** | | |
| compose.noproxy.yaml | Direct access on port 8080 | Default |
| compose.proxy.yaml | Traefik HTTP proxy on port 80 | |
| compose.https.yaml | Traefik HTTPS with Let's Encrypt | Requires `SITES` and `LETSENCRYPT_EMAIL` |
| **Multi-Bench** | | |
| compose.multi-bench.yaml | Multi-bench setup | For multiple projects |
| compose.multi-bench-ssl.yaml | Multi-bench with SSL | |
| **Custom Domain** | | |
| compose.custom-domain.yaml | Add custom domain | Set `BASE_SITE` |
| compose.custom-domain-ssl.yaml | Custom domain with SSL | |
| **Other** | | |
| compose.traefik.yaml | Standalone Traefik | |
| compose.traefik-ssl.yaml | Traefik with SSL | |
| compose.backup-cron.yaml | Backup scheduling | |

**Example - HTTPS with MariaDB and Redis:**

```bash
docker compose --env-file custom.env -p frappe \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.https.yaml \
  config > compose.custom.yaml
```

---

## Offline Server Setup

Deploy on a server connected via SSH without internet access.

### On Machine with Internet

1. **Build and save images:**

```bash
docker save -o frappe-images.tar \
  custom:15 \
  mariadb:10.11 \
  redis:alpine \
  nginx:alpine \
  node:18-alpine
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

3. **Start containers:**

```bash
cd /home/user/frappe
docker compose -p frappe -f compose.custom.yaml up -d
```

4. **Create site:**

```bash
docker compose -p frappe exec backend bench new-site <sitename> \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --install-app erpnext \
  --admin-password your_admin_password
```

---

**Done!** Your Frappe bench is running with ERPNext installed.
