# Security Guide

Security best practices and hardening for NodeLoom self-hosted deployments.

## Security Checklist

- [ ] Strong passwords generated for all services
- [ ] JWT secret is 256+ bits
- [ ] TLS/HTTPS enabled
- [ ] Database not exposed to public
- [ ] Redis not exposed to public
- [ ] Regular backups configured
- [ ] Audit logging enabled
- [ ] Network policies configured (Kubernetes)

## Secrets Management

### Generate Strong Secrets

```bash
# JWT Secret (256-bit minimum)
openssl rand -base64 64

# Database password
openssl rand -base64 32

# Redis password
openssl rand -base64 32
```

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

2. **Create Nginx configuration:**
   ```nginx
   # nginx/conf.d/default.conf
   server {
       listen 80;
       server_name _;
       return 301 https://$host$request_uri;
   }

   server {
       listen 443 ssl http2;
       server_name app.yourdomain.com;

       ssl_certificate /etc/nginx/ssl/cert.pem;
       ssl_certificate_key /etc/nginx/ssl/key.pem;
       ssl_protocols TLSv1.2 TLSv1.3;
       ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;

       location / {
           proxy_pass http://frontend:3000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }

   server {
       listen 443 ssl http2;
       server_name api.yourdomain.com;

       ssl_certificate /etc/nginx/ssl/cert.pem;
       ssl_certificate_key /etc/nginx/ssl/key.pem;

       location / {
           proxy_pass http://backend:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-Proto $scheme;

           # WebSocket support
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
       }
   }
   ```

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

NodeLoom includes built-in RBAC with these roles:
- **Admin** - Full access
- **Builder** - Create/edit workflows
- **Operator** - Execute workflows
- **Viewer** - Read-only access

### Audit Logging

All actions are logged with:
- User ID
- Action type
- Timestamp
- IP address
- Resource affected

View logs in the Audit section of the UI.

### API Security

- All API endpoints require authentication
- JWT tokens expire after 24 hours
- Refresh tokens for seamless re-authentication
- Rate limiting enabled by default

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
   docker scan ghcr.io/reedzerrad/nodeloom-backend:latest
   ```

## Incident Response

1. **Isolate affected systems**
2. **Preserve logs for analysis**
3. **Rotate all secrets**
4. **Review audit logs**
5. **Contact support@nodeloom.io**
