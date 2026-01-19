# Troubleshooting Guide

Common issues and solutions for AgentHero self-hosted deployments.

## Quick Diagnostics

### Docker Compose

```bash
# Check all services status
docker-compose ps

# Check logs for all services
docker-compose logs

# Check specific service
docker-compose logs backend
docker-compose logs postgres
docker-compose logs redis

# Check resource usage
docker stats
```

### Kubernetes

```bash
# Check pod status
kubectl get pods -n agenthero

# Check pod events
kubectl describe pod <pod-name> -n agenthero

# Check logs
kubectl logs -n agenthero deployment/backend
kubectl logs -n agenthero deployment/frontend

# Check resource usage
kubectl top pods -n agenthero
```

## Common Issues

### 1. Backend Not Starting

**Symptoms:**
- Backend container keeps restarting
- Health check fails

**Check logs:**
```bash
docker-compose logs backend | tail -100
```

**Common causes:**

| Error | Cause | Solution |
|-------|-------|----------|
| `Connection refused: postgres:5432` | PostgreSQL not ready | Wait or check postgres container |
| `Authentication failed` | Wrong DB password | Check POSTGRES_PASSWORD in .env |
| `JWT_SECRET not set` | Missing config | Set JWT_SECRET in .env |
| `Out of memory` | Insufficient RAM | Increase memory limits |

### 2. Database Connection Issues

**Test connection:**
```bash
docker-compose exec postgres psql -U agenthero -d agenthero -c "SELECT 1;"
```

**Check PostgreSQL logs:**
```bash
docker-compose logs postgres | tail -50
```

**Reset database (destructive):**
```bash
docker-compose down -v
docker-compose up -d
```

### 3. Redis Connection Issues

**Test connection:**
```bash
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping
```

**Common causes:**
- Wrong REDIS_PASSWORD
- Redis not started
- Network issues

### 4. Frontend Shows "Failed to fetch"

**Check:**
1. Backend is running: `curl http://localhost:8080/actuator/health`
2. CORS is configured correctly
3. PUBLIC_API_URL is correct in frontend config

**Fix CORS (if needed):**
Ensure backend allows frontend origin in CORS configuration.

### 5. Cannot Login / Auth Issues

**Check JWT configuration:**
```bash
# Ensure JWT_SECRET is set
docker-compose exec backend env | grep JWT
```

**Check logs for auth errors:**
```bash
docker-compose logs backend | grep -i "auth\|jwt\|token"
```

### 6. Slow Performance

**Database:**
```bash
# Run VACUUM ANALYZE
docker-compose exec postgres psql -U agenthero agenthero -c "VACUUM ANALYZE;"

# Check slow queries
docker-compose exec postgres psql -U agenthero agenthero -c "
  SELECT query, calls, mean_time
  FROM pg_stat_statements
  ORDER BY mean_time DESC
  LIMIT 10;
"
```

**Application:**
```bash
# Check memory usage
docker stats

# Increase memory if needed (docker-compose.yml)
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 4G
```

### 7. WebSocket Not Connecting

**Symptoms:**
- Real-time updates not working
- "WebSocket connection failed" in browser console

**Check:**
1. Nginx/Ingress configured for WebSocket
2. Proxy timeout settings sufficient

**Nginx configuration:**
```nginx
location /ws {
    proxy_pass http://backend:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 300s;
}
```

### 8. Workflow Execution Fails

**Check executor logs:**
```bash
docker-compose logs backend | grep -i "execution\|workflow"
```

**Common causes:**
- Missing AI API keys
- External service not reachable
- Timeout issues

### 9. Out of Disk Space

**Check disk usage:**
```bash
# Docker
docker system df
docker system prune -a  # Clean unused images

# PostgreSQL
docker-compose exec postgres psql -U agenthero agenthero -c "
  SELECT pg_size_pretty(pg_database_size('agenthero'));
"
```

### 10. SSL/TLS Certificate Issues

**Check certificate:**
```bash
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

**cert-manager issues:**
```bash
kubectl describe certificate -n agenthero
kubectl describe certificaterequest -n agenthero
```

## Health Checks

### Backend Health

```bash
curl http://localhost:8080/actuator/health
```

Expected response:
```json
{"status":"UP"}
```

### Database Health

```bash
docker-compose exec postgres pg_isready -U agenthero
```

### Redis Health

```bash
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping
```

## Getting Help

1. **Check logs** - Most issues are visible in logs
2. **Search existing issues** - https://github.com/reedzerrad/agenthero-self-hosted/issues
3. **Create new issue** - Include logs and configuration (redact secrets)
4. **Contact support** - support@agenthero.io

## Useful Commands Reference

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart backend

# Force recreate containers
docker-compose up -d --force-recreate

# View real-time logs
docker-compose logs -f backend

# Execute command in container
docker-compose exec backend bash

# Check container resource usage
docker stats --no-stream

# Kubernetes: Force pod restart
kubectl rollout restart deployment/backend -n agenthero
```
