# Troubleshooting Guide

Common issues and solutions for NodeLoom self-hosted deployments.

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
kubectl get pods -n nodeloom

# Check pod events
kubectl describe pod <pod-name> -n nodeloom

# Check logs
kubectl logs -n nodeloom deployment/backend
kubectl logs -n nodeloom deployment/frontend

# Check resource usage
kubectl top pods -n nodeloom
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
docker-compose exec postgres psql -U nodeloom -d nodeloom -c "SELECT 1;"
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

### 4. Encryption Key Issues

**Symptoms:**
- Credentials that previously worked now fail
- Errors like `AEADBadTagException` or `BadPaddingException` in logs
- OAuth connections and stored API keys stop working

**Cause:** The `APP_ENCRYPTION_KEY` was changed or lost. All stored credentials (OAuth tokens, API keys, database passwords) are encrypted with AES-256-GCM using this key.

**Important:**
- **If you changed the key**, there is no way to recover previously encrypted credentials. Users must re-connect all OAuth integrations and re-enter API keys.
- **If you lost the key**, the same applies — encrypted data is permanently unreadable.
- **Always back up** `APP_ENCRYPTION_KEY` separately from database backups.

**Check:**
```bash
# Verify the key is set
docker-compose exec backend env | grep APP_ENCRYPTION_KEY

# Check for decryption errors in logs
docker-compose logs backend | grep -i "decrypt\|encryption\|AES\|BadTag"
```

**Recovery:**
1. Set a new `APP_ENCRYPTION_KEY` in `.env`
2. Restart: `docker-compose up -d`
3. Have all users re-connect their OAuth integrations and re-enter credentials

### 5. Frontend Shows "Failed to fetch" / CORS Errors

**Symptoms:**
- Browser console shows `CORS policy` errors
- API calls blocked with `Access-Control-Allow-Origin` errors
- Frontend loads but can't communicate with backend

**Check:**
1. Backend is running: `curl http://localhost:8080/actuator/health`
2. `APP_CORS_ALLOWED_ORIGINS` matches your frontend URL exactly (including protocol and port)
3. `PUBLIC_API_URL` is correct in frontend config

**Fix CORS:**
```bash
# In .env, set to your actual frontend domain (no trailing slash)
APP_CORS_ALLOWED_ORIGINS=https://app.yourdomain.com

# For multiple domains
APP_CORS_ALLOWED_ORIGINS=https://app.yourdomain.com,https://admin.yourdomain.com

# Restart backend
docker-compose restart backend
```

**Common mistakes:**
- Trailing slash: `https://app.example.com/` (wrong) vs `https://app.example.com` (correct)
- Missing protocol: `app.example.com` (wrong) vs `https://app.example.com` (correct)
- Wildcard `*` — never use in production

### 6. APP_BASE_URL / APP_FRONTEND_URL Misconfiguration

**Symptoms:**
- OAuth callbacks redirect to `localhost` instead of your domain
- Password reset emails contain wrong links
- Webhook URLs point to wrong address
- Widget embed URLs are broken

**Cause:** `APP_BASE_URL` and/or `APP_FRONTEND_URL` are not set to your production domains.

**Fix:**
```bash
# In .env — set to your actual domains (no trailing slash)
APP_BASE_URL=https://api.yourdomain.com
APP_FRONTEND_URL=https://app.yourdomain.com

# Restart
docker-compose restart backend
```

**What each URL affects:**
- `APP_BASE_URL` — OAuth callback URLs, webhook endpoints, SCIM endpoints, widget API calls
- `APP_FRONTEND_URL` — Email links (password reset, invitations), Stripe redirect URLs

### 7. Cannot Login / Auth Issues

**Check JWT configuration:**
```bash
# Ensure JWT_SECRET is set
docker-compose exec backend env | grep JWT
```

**Check logs for auth errors:**
```bash
docker-compose logs backend | grep -i "auth\|jwt\|token"
```

### 8. Slow Performance

**Database:**
```bash
# Run VACUUM ANALYZE
docker-compose exec postgres psql -U nodeloom nodeloom -c "VACUUM ANALYZE;"

# Check slow queries
docker-compose exec postgres psql -U nodeloom nodeloom -c "
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

### 9. WebSocket Not Connecting

**Symptoms:**
- Real-time updates not working
- "WebSocket connection failed" in browser console

**Check:**
1. `APP_CORS_ALLOWED_ORIGINS` includes your frontend domain (WebSocket connections respect CORS)
2. Nginx/Ingress configured for WebSocket upgrade
3. Proxy timeout settings sufficient (300s+ recommended)

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

### 10. Workflow Execution Fails

**Check executor logs:**
```bash
docker-compose logs backend | grep -i "execution\|workflow"
```

**Common causes:**
- Missing AI API keys
- External service not reachable
- Timeout issues

### 11. Out of Disk Space

**Check disk usage:**
```bash
# Docker
docker system df
docker system prune -a  # Clean unused images

# PostgreSQL
docker-compose exec postgres psql -U nodeloom nodeloom -c "
  SELECT pg_size_pretty(pg_database_size('nodeloom'));
"
```

### 12. SSL/TLS Certificate Issues

**Check certificate:**
```bash
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

**cert-manager issues:**
```bash
kubectl describe certificate -n nodeloom
kubectl describe certificaterequest -n nodeloom
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
docker-compose exec postgres pg_isready -U nodeloom
```

### Redis Health

```bash
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping
```

## Getting Help

1. **Check logs** - Most issues are visible in logs
2. **Search existing issues** - https://github.com/reedzerrad/nodeloom-self-hosted/issues
3. **Create new issue** - Include logs and configuration (redact secrets)
4. **Contact support** - support@nodeloom.io

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
kubectl rollout restart deployment/backend -n nodeloom
```
