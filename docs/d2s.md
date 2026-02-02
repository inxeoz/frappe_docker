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
> Checkout [Env Var](02-setup/04-env-variables.md)

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

> Checkout [Custom apps](02-setup/02-build-setup.md)

```bash
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --tag=custom:15 \
  --file=images/layered/Containerfile .
```

## 5. Create Compose File

```bash
docker compose --env-file envs/alis.env -p frappe \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.traefik-one.yaml \
  config > compose/alis.yaml
```

## 6. Start Containers

```bash
docker compose -p alis -f compose/alis.yaml up -d
```
use these options as required 

```
--pull never          # Never pull, use local only
--no-pull             # Skip pull phase entirely
--build no-cache      # Build without cache pulls
docker build --no-cache --pull never .
```
use these options to scale

```
--scale backend=3
--scale redis-queue=3
```


## 7. Create Site

```bash
docker compose -p frappe exec backend bench new-site <sitename> \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --admin-password your_admin_password
```
if you used apps.json to install custom app like erpnext 
then use 

```
  --install-app erpnext
  --install-app app_name 
```

## 8. Access Site

Open browser: `http://localhost:PORT_NUMBER`

Try Curl
```
curl --resolve SITE_NAME:PORT_NUMBER:127.0.0.1 http://SITE_NAME:PORT_NUMBER
```
example 

```
curl --resolve frontend.local:8080:127.0.0.1 http://frontend.local:8080
```
Access using direct SITE_NAME:PORT
for that point resolve to 127.0.0.1

add ``127.0.0.1 SITE_NAME`` to /etc/hosts

example
```
127.0.0.1        localhost
::1              localhost
127.0.0.1 SITE_NAME
```
another example
```
curl -H "Host: witherp" http://127.0.0.1:8100
```
if 8100 is running reverse proxy 

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
