# Upgrading Guide

How to upgrade NodeLoom to a new version.

## Before Upgrading

1. **Read release notes** for breaking changes
2. **Backup your database** (see [Backup Guide](backup-restore.md))
3. **Test in staging** if available
4. **Schedule maintenance window** for production

## Version Compatibility

| From Version | To Version | Notes |
|--------------|------------|-------|
| 1.0.x | 1.0.y | Patch update, no migration |
| 1.0.x | 1.1.x | Minor update, auto-migration |
| 1.x.x | 2.x.x | Major update, see migration guide |

## Docker Compose Upgrade

### Standard Upgrade

```bash
# 1. Backup database
docker-compose exec postgres pg_dump -U nodeloom nodeloom > backup_before_upgrade.sql

# 2. Pull new images
docker-compose pull

# 3. Restart services
docker-compose up -d

# 4. Check logs for migration status
docker-compose logs backend | grep -i migration

# 5. Verify application
curl http://localhost:8080/actuator/health
```

### Upgrade to Specific Version

```bash
# Edit .env file
NODELOOM_VERSION=1.2.0

# Pull and restart
docker-compose pull
docker-compose up -d
```

### Rollback

```bash
# 1. Stop services
docker-compose down

# 2. Set previous version
# Edit .env: NODELOOM_VERSION=1.1.0

# 3. Restore database
cat backup_before_upgrade.sql | docker-compose exec -T postgres psql -U nodeloom nodeloom

# 4. Start with old version
docker-compose up -d
```

## Kubernetes Upgrade

### Using kubectl

```bash
# 1. Backup
PG_POD=$(kubectl get pods -n nodeloom -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n nodeloom $PG_POD -- pg_dump -U nodeloom nodeloom > backup.sql

# 2. Update image tags in manifests
sed -i 's/nodeloom-backend:1.1.0/nodeloom-backend:1.2.0/g' k8s/backend.yaml
sed -i 's/nodeloom-frontend:1.1.0/nodeloom-frontend:1.2.0/g' k8s/frontend.yaml

# 3. Apply updates
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

# 4. Watch rollout
kubectl rollout status deployment/backend -n nodeloom

# 5. Verify
kubectl get pods -n nodeloom
```

### Using Helm

```bash
# 1. Backup
./scripts/backup.sh

# 2. Update values
# Edit my-values.yaml:
# backend:
#   image:
#     tag: "1.2.0"
# frontend:
#   image:
#     tag: "1.2.0"

# 3. Upgrade
helm upgrade nodeloom ./helm/nodeloom \
  --namespace nodeloom \
  -f my-values.yaml

# 4. Watch rollout
kubectl rollout status deployment/nodeloom-backend -n nodeloom

# 5. Verify
helm status nodeloom -n nodeloom
```

### Rollback with Helm

```bash
# List history
helm history nodeloom -n nodeloom

# Rollback to previous release
helm rollback nodeloom 1 -n nodeloom

# Restore database if needed
cat backup.sql | kubectl exec -i -n nodeloom $PG_POD -- psql -U nodeloom nodeloom
```

## Database Migrations

NodeLoom uses Flyway for database migrations. Migrations run automatically on startup.

### Check Migration Status

```bash
# Docker Compose
docker-compose logs backend | grep -i flyway

# Kubernetes
kubectl logs -n nodeloom deployment/backend | grep -i flyway
```

### Manual Migration (if needed)

```bash
# Connect to database
docker-compose exec postgres psql -U nodeloom nodeloom

# Check migration history
SELECT * FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 10;
```

## Zero-Downtime Upgrade

For production environments:

1. **Ensure multiple replicas:**
   ```yaml
   backend:
     replicaCount: 3
   ```

2. **Configure rolling update:**
   ```yaml
   spec:
     strategy:
       type: RollingUpdate
       rollingUpdate:
         maxSurge: 1
         maxUnavailable: 0
   ```

3. **Use readiness probes:**
   The default configuration includes readiness probes that prevent traffic to pods until they're ready.

## Troubleshooting Upgrades

### Migration Failed

```bash
# Check logs
docker-compose logs backend | grep -i error

# If migration failed, restore backup
docker-compose down
cat backup_before_upgrade.sql | docker-compose exec -T postgres psql -U nodeloom nodeloom
docker-compose up -d
```

### Application Not Starting

```bash
# Check backend logs
docker-compose logs backend

# Common issues:
# - Database connection: Check POSTGRES_PASSWORD
# - Redis connection: Check REDIS_PASSWORD
# - Memory issues: Increase container memory limits
```

### Performance Issues After Upgrade

```bash
# Check resource usage
docker stats

# Kubernetes
kubectl top pods -n nodeloom

# May need to run VACUUM ANALYZE after major upgrade
docker-compose exec postgres psql -U nodeloom nodeloom -c "VACUUM ANALYZE;"
```
