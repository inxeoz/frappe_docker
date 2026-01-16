# Scaling Frappe Bench with Docker

This guide covers the necessary steps to scale your Frappe Bench setup, including multi-service scaling for setups like multiple subdomains (`blog.inxeoz.com`, `hrms.inxeoz.com`). Scaling can be done vertically (increasing resources) or horizontally (adding containers/services).

---

## 1. Scaling Backend Services

Backend services handle most of the workload and should be the first to scale. Use Docker Compose to scale.

### Scale Using Docker Compose

To scale the backend service:

```bash
docker compose -p frappe -f compose.custom.yaml up -d --scale backend=3
```

This will create 3 backend containers.

### Ensure Load Balancer

- Use an override file such as `compose.proxy.yaml` or `compose.https.yaml` to configure **Traefik** or **Nginx** as a load balancer.
- Example to configure Traefik with your setup:

```bash
docker compose --env-file custom.env -p frappe \
  -f compose.yaml \
  -f overrides/compose.proxy.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  config > compose.custom.yaml
```
i think 
```
  -f overrides/compose.https.yaml \
```
for https not for http

---

## 2. Scaling Redis for Caching and Queuing

Redis handles caches and queues. You can scale Redis to improve performance.

### Scale Redis Queue

Use Docker Compose to scale Redis for queue services:

```bash
docker compose -p frappe -f compose.custom.yaml up -d --scale redis-queue=3
```

Ensure the backend containers are configured to connect to these scaled Redis queues.

---

## 3. Scaling Database Services (MariaDB or PostgreSQL)

Scaled database setups enhance performance under heavy traffic or multi-site deployments.

### Use Clustered Database

Set up read replicas for MariaDB using the `compose.mariadb.yaml` or `compose.mariadb-shared.yaml` overrides:

```yaml
mariadb-replica:
  image: mariadb:11.8
  command: mysqld --server-id=102 --log-bin
  environment:
    - MYSQL_ROOT_PASSWORD=your_secure_password
```

Ensure replication is configured between master and replica databases.

### Kubernetes for Auto-scaling Databases

For large-scale setups, consider moving databases to Kubernetes with Horizontal Pod Autoscalers.

---

## 4. Scaling Multi-Service Setup (Multiple Sites/Subdomains)

To serve multiple services (e.g., `blog.inxeoz.com`, `hrms.inxeoz.com`):

### Step 1: Create Multi-Sites

For each service, create a new site:

```bash
docker compose -p frappe exec backend bench new-site blog.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --admin-password your_admin_password

docker compose -p frappe exec backend bench new-site hrms.inxeoz.com \
  --mariadb-user-host-login-scope='%' \
  --db-root-password your_secure_password \
  --admin-password your_admin_password
```

Install apps (if needed):

```bash
docker compose -p frappe exec backend bench --site blog.inxeoz.com install-app erpnext
docker compose -p frappe exec backend bench --site hrms.inxeoz.com install-app erpnext
```

### Step 2: Update Compose File

Generate the `compose.custom.yaml` file to include Traefik or a proxy:

```bash
docker compose --env-file custom.env -p frappe \
  -f compose.yaml \
  -f overrides/compose.proxy.yaml \
  -f overrides/compose.custom-domain.yaml \
  -f overrides/compose.custom-domain-ssl.yaml \
  config > compose.custom.yaml
```

### Step 3: DNS Configuration
- Add `A` records for your subdomains pointing to the server's IP address:

  ```txt
  blog.inxeoz.com  -> 123.123.123.123
  hrms.inxeoz.com  -> 123.123.123.123
  ```

- For local testing, update `/etc/hosts`:

  ```txt
  127.0.0.1       blog.inxeoz.com
  127.0.0.1       hrms.inxeoz.com
  ```

---

## 5. Moving to Kubernetes for Advanced Scaling

For production-grade scaling, migrate to Kubernetes:

### Convert Docker Compose to Kubernetes

Use tools like **Kompose**:

```bash
kompose convert -f compose.custom.yaml
```

### Set Up Horizontal Pod Autoscaler (HPA)

Example for scaling backend pods:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-scaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
```

### Use Kubernetes Ingress Controllers

Deploy **Traefik** or **Nginx Ingress** for custom domains and SSL.

---

## 6. Vertical Scaling (Increasing Resources)

If horizontal scaling is not feasible, you can increase resource limits for containers in `docker-compose.override.yaml`:

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: "8G"
        reservations:
          cpus: "2"
          memory: "4G"
```

---

## 7. Monitoring Performance

Use monitoring tools to track system performance:
- **Prometheus/Grafana**: Metrics for containers.
- **Percona Monitoring and Management**: Metrics for MariaDB.
- **Frappe Bench Logs**: To troubleshoot slow requests.

---

## 8. Backup Strategy

Use the `compose.backup-cron.yaml` to schedule periodic database backups:

```bash
docker compose -p frappe -f compose.backup-cron.yaml up -d
```

Store backups on a remote server or cloud storage.

---

## Done!

With this setup, your Frappe Bench environment is scalable and ready to handle high traffic, multiple services, and growth in user demand.
