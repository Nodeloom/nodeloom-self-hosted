# Backup & Restore Guide

Protect your AgentHero data with regular backups.

## What to Backup

| Component | Data | Priority |
|-----------|------|----------|
| PostgreSQL | Workflows, users, credentials, audit logs | **Critical** |
| Redis | Session cache, rate limits | Low (regenerated) |
| Files | Uploaded files, workflow attachments | Medium |

## Docker Compose Backups

### Database Backup

**Manual backup:**
```bash
# Create backup
docker-compose exec postgres pg_dump -U agenthero agenthero > backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed backup
docker-compose exec postgres pg_dump -U agenthero agenthero | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

**Automated backup script:**
```bash
#!/bin/bash
# scripts/backup.sh

BACKUP_DIR="/path/to/backups"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker-compose exec -T postgres pg_dump -U agenthero agenthero | gzip > $BACKUP_DIR/agenthero_$TIMESTAMP.sql.gz

# Backup files volume
docker run --rm -v agenthero-self-hosted_postgres_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/files_$TIMESTAMP.tar.gz -C /data .

# Remove old backups
find $BACKUP_DIR -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_DIR/agenthero_$TIMESTAMP.sql.gz"
```

**Schedule with cron:**
```bash
# Run daily at 2 AM
0 2 * * * /path/to/scripts/backup.sh >> /var/log/agenthero-backup.log 2>&1
```

### Database Restore

```bash
# Stop the application
docker-compose stop backend frontend

# Restore from backup
gunzip -c backup_20240101_120000.sql.gz | docker-compose exec -T postgres psql -U agenthero agenthero

# Start the application
docker-compose start backend frontend
```

## Kubernetes Backups

### Using kubectl

**Manual backup:**
```bash
# Get PostgreSQL pod name
PG_POD=$(kubectl get pods -n agenthero -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Create backup
kubectl exec -n agenthero $PG_POD -- pg_dump -U agenthero agenthero | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Using Velero (Recommended)

1. **Install Velero:**
   ```bash
   velero install \
     --provider aws \
     --bucket your-backup-bucket \
     --secret-file ./credentials-velero
   ```

2. **Create backup:**
   ```bash
   velero backup create agenthero-backup --include-namespaces agenthero
   ```

3. **Schedule backups:**
   ```bash
   velero schedule create agenthero-daily \
     --schedule="0 2 * * *" \
     --include-namespaces agenthero \
     --ttl 720h
   ```

4. **Restore:**
   ```bash
   velero restore create --from-backup agenthero-backup
   ```

### Using CronJob

```yaml
# k8s/backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: agenthero
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h postgres -U agenthero agenthero | gzip > /backup/agenthero_$(date +%Y%m%d).sql.gz
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: agenthero-secrets
                  key: POSTGRES_PASSWORD
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-volume
            persistentVolumeClaim:
              claimName: backup-pvc
```

## Disaster Recovery

### Full Recovery Procedure

1. **Deploy fresh infrastructure:**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/secrets.yaml
   kubectl apply -f k8s/
   ```

2. **Wait for PostgreSQL to be ready:**
   ```bash
   kubectl wait --for=condition=ready pod -l app=postgres -n agenthero --timeout=120s
   ```

3. **Restore database:**
   ```bash
   PG_POD=$(kubectl get pods -n agenthero -l app=postgres -o jsonpath='{.items[0].metadata.name}')
   gunzip -c backup.sql.gz | kubectl exec -i -n agenthero $PG_POD -- psql -U agenthero agenthero
   ```

4. **Verify application:**
   ```bash
   kubectl get pods -n agenthero
   curl https://api.yourdomain.com/actuator/health
   ```

## Testing Backups

**Always test your backups!**

```bash
# Create a test environment
docker-compose -f docker-compose.yml -f docker-compose.test.yml up -d

# Restore backup to test environment
gunzip -c backup.sql.gz | docker-compose exec -T postgres psql -U agenthero agenthero_test

# Verify data integrity
docker-compose exec postgres psql -U agenthero agenthero_test -c "SELECT COUNT(*) FROM workflows;"
```

## Backup Checklist

- [ ] Daily automated backups configured
- [ ] Backups stored off-site (different region/cloud)
- [ ] Backup retention policy defined (30 days recommended)
- [ ] Restore procedure tested monthly
- [ ] Backup monitoring/alerting configured
- [ ] Encryption enabled for backup storage
