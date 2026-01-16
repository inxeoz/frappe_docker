docker compose -p frappe -f compose.custom.yaml down -v

docker compose --env-file custom.env -p frappe   -f compose.yaml   -f overrides/compose.proxy.yaml   -f overrides/compose.mariadb.yaml   -f overrides/compose.redis.yaml   config > compose.custom.yaml

docker compose -p frappe -f compose.custom.yaml up -d --scale backend=2 --scale redis-queue=2


docker compose -p frappe exec backend bench new-site s1.inxeoz.com   --mariadb-user-host-login-scope='%'   --db-root-password 0000   --admin-password 0000
