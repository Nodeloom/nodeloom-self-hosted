# Security Guide

Security best practices and hardening for NodeLoom self-hosted deployments.

## Security Checklist

- [ ] All required secrets generated with strong random values
- [ ] `APP_ENCRYPTION_KEY` stored securely and backed up
- [ ] JWT secret is 256+ bits
- [ ] TLS/HTTPS enabled for all public endpoints
- [ ] Database not exposed to public network
- [ ] Redis not exposed to public network
- [ ] `FORWARD_HEADERS_STRATEGY` set to `NATIVE` (behind proxy)
- [ ] `APP_CORS_ALLOWED_ORIGINS` set to your actual frontend domain
- [ ] `APP_BASE_URL` and `APP_FRONTEND_URL` set to production domains
- [ ] Regular backups configured and tested
- [ ] Audit logging enabled
- [ ] Network policies configured (Kubernetes)
- [ ] CAPTCHA enabled if registration is exposed
- [ ] SCIM tokens managed securely (if using SSO/SAML)
- [ ] Container images kept up to date

## Secrets Management

### Required Secrets

| Secret | Purpose | Impact if Compromised |
|--------|---------|----------------------|
| `APP_ENCRYPTION_KEY` | Encrypts all stored credentials (AES-256-GCM) | All credentials exposed |
| `JWT_SECRET` | Signs authentication tokens | Account takeover |
| `APP_ADMIN_API_KEY` | Backoffice API access | Admin-level access |
| `POSTGRES_PASSWORD` | Database access | Full data access |
| `REDIS_PASSWORD` | Cache/session access | Session hijacking |

### Generate Strong Secrets

```bash
# Encryption key (AES-256-GCM) - BACK THIS UP!
openssl rand -base64 32

# JWT Secret (256-bit minimum)
openssl rand -base64 64

# Admin API key
openssl rand -base64 32

# Database password
openssl rand -base64 32

# Redis password
openssl rand -base64 32
```

### Encryption Key Management

The `APP_ENCRYPTION_KEY` is the most critical secret in a NodeLoom deployment:

- **All stored credentials** (API keys, OAuth tokens, database passwords) are encrypted with this key using AES-256-GCM
- **If you lose this key**, all stored credentials become permanently unreadable
- **If you change this key**, existing encrypted credentials cannot be decrypted
- **Back up this key** in a secure location separate from your database backups
- **Never reuse** this key across environments (dev, staging, production)
- The application **will not start** without a valid encryption key in production

### Kubernetes Secrets

**Never commit secrets to git!**

Use external secrets manager:

```yaml
# Using External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: nodeloom-secrets
  namespace: nodeloom
spec:
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: nodeloom-secrets
  data:
    - secretKey: APP_ENCRYPTION_KEY
      remoteRef:
        key: nodeloom/encryption-key
    - secretKey: JWT_SECRET
      remoteRef:
        key: nodeloom/jwt-secret
    - secretKey: POSTGRES_PASSWORD
      remoteRef:
        key: nodeloom/postgres-password
```

## TLS/HTTPS Configuration

### Docker Compose with Nginx

1. **Generate or obtain certificates:**
   ```bash
   mkdir -p nginx/ssl
   # Place your certificates in nginx/ssl/
   # - cert.pem
   # - key.pem
   ```

2. **The included Nginx config** (`nginx/conf.d/default.conf`) provides:
   - HTTP to HTTPS redirect
   - Separate server blocks for frontend (`app.yourdomain.com`) and backend API (`api.yourdomain.com`)
   - WebSocket support for real-time features
   - Security headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy)

3. **Enable Nginx profile:**
   ```bash
   docker-compose --profile with-nginx up -d
   ```

### Kubernetes with cert-manager

1. **Install cert-manager:**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **Create ClusterIssuer:**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
         - http01:
             ingress:
               class: nginx
   ```

3. **Update Ingress:**
   ```yaml
   metadata:
     annotations:
       cert-manager.io/cluster-issuer: "letsencrypt-prod"
   spec:
     tls:
       - hosts:
           - app.yourdomain.com
           - api.yourdomain.com
         secretName: nodeloom-tls
   ```

## Network Security

### Docker Compose

Services are isolated on internal network. Only expose necessary ports:

```yaml
services:
  postgres:
    # Don't expose to host in production
    # ports:
    #   - "5432:5432"
    networks:
      - nodeloom-network

  backend:
    ports:
      - "127.0.0.1:8080:8080"  # Localhost only
    networks:
      - nodeloom-network
```

### Kubernetes Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: nodeloom
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - port: 5432
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - port: 6379
    - to:  # Allow external API calls
        - ipBlock:
            cidr: 0.0.0.0/0
      ports:
        - port: 443
```

## CORS Configuration

Set `APP_CORS_ALLOWED_ORIGINS` to your actual frontend domain(s). This controls which origins can make API requests:

```bash
# Single domain
APP_CORS_ALLOWED_ORIGINS=https://app.yourdomain.com

# Multiple domains (comma-separated)
APP_CORS_ALLOWED_ORIGINS=https://app.yourdomain.com,https://admin.yourdomain.com
```

**Never use wildcards in production.** WebSocket connections also respect this setting.

## Proxy Headers

When NodeLoom is behind a reverse proxy (nginx, ALB, Cloudflare), set:

```bash
FORWARD_HEADERS_STRATEGY=NATIVE
```

This ensures:
- `X-Forwarded-For` is trusted for client IP detection (rate limiting, audit logs)
- `X-Forwarded-Proto` is trusted for HTTPS detection (cookie security)
- Without this, rate limiting uses proxy IP instead of client IP

## Database Security

### PostgreSQL

1. **Use strong passwords** (32+ characters)
2. **Enable SSL connections:**
   ```yaml
   postgres:
     command: postgres -c ssl=on -c ssl_cert_file=/var/lib/postgresql/server.crt -c ssl_key_file=/var/lib/postgresql/server.key
   ```
3. **Restrict access to localhost/internal network**
4. **Regular backups with encryption**

### Redis

1. **Require password authentication**
2. **Don't expose to public network**
3. **Use TLS for Redis connections** (Redis 6+)

## Application Security

### RBAC

NodeLoom includes built-in RBAC with 5 roles:
- **Admin** - Full access
- **Builder** - Create/edit workflows, manage credentials
- **Operator** - Execute workflows
- **Viewer** - Read-only access
- **Compliance Officer** - View-only + audit logs + compliance dashboard

### SCIM 2.0 Provisioning

For enterprise SSO integration (Okta, Azure AD, OneLogin):
- Bearer token authentication with per-token IP allowlisting (CIDR support)
- Rate limiting configurable via `SCIM_RATE_LIMIT_PER_MINUTE`
- Group-to-role mapping (Admins->ADMIN, Builders->BUILDER, etc.)

### Audit Logging

All actions are logged with:
- User ID
- Action type
- Timestamp
- IP address
- Resource affected
- SHA-256 cryptographic hash chain for tamper detection

View logs in the Audit section of the UI.

### API Security

- All API endpoints require authentication
- JWT tokens expire after 24 hours
- Refresh tokens for seamless re-authentication
- Rate limiting enabled by default
- Widget endpoints rate limited separately (30 req/min per IP)

## Container Security

### Run as Non-Root

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
```

### Read-Only Filesystem

```yaml
securityContext:
  readOnlyRootFilesystem: true
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

### Resource Limits

Always set resource limits:

```yaml
resources:
  limits:
    cpu: "2"
    memory: "4Gi"
  requests:
    cpu: "500m"
    memory: "1Gi"
```

## Security Updates

1. **Subscribe to security advisories**
2. **Update regularly:**
   ```bash
   # Docker
   docker-compose pull
   docker-compose up -d

   # Helm
   helm upgrade nodeloom ./helm/nodeloom -n nodeloom
   ```
3. **Monitor for vulnerabilities:**
   ```bash
   docker scan ghcr.io/nodeloom/nodeloom-backend:latest
   ```

## Incident Response

1. **Isolate affected systems**
2. **Preserve logs for analysis**
3. **Rotate all secrets** (especially `APP_ENCRYPTION_KEY` if compromised)
4. **Review audit logs** (check hash chain integrity via Compliance Dashboard)
5. **Contact support@nodeloom.io**
