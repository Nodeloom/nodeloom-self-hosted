# Configuration Reference

Complete reference for all AgentHero configuration options.

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `JWT_SECRET` | Secret key for JWT tokens (min 256 bits) | `openssl rand -base64 64` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `secure_password_here` |
| `REDIS_PASSWORD` | Redis password | `secure_password_here` |

### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `agenthero` | Database name |
| `POSTGRES_USER` | `agenthero` | Database user |
| `POSTGRES_PASSWORD` | - | Database password (required) |
| `POSTGRES_PORT` | `5432` | PostgreSQL port |

### Redis Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PASSWORD` | - | Redis password (required) |
| `REDIS_PORT` | `6379` | Redis port |

### Application Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_PORT` | `8080` | Backend API port |
| `FRONTEND_PORT` | `3000` | Frontend port |
| `PUBLIC_API_URL` | `http://localhost:8080` | Public URL for API |
| `SPRING_PROFILES_ACTIVE` | `production` | Spring profile |

### AI Provider Configuration

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key for GPT models |
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude models |
| `GOOGLE_AI_API_KEY` | Google AI API key for Gemini models |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI API key |
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI endpoint URL |

### OAuth Configuration

| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `GITHUB_CLIENT_ID` | GitHub OAuth client ID |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth client secret |
| `SLACK_CLIENT_ID` | Slack OAuth client ID |
| `SLACK_CLIENT_SECRET` | Slack OAuth client secret |

### Stripe Configuration (Billing)

| Variable | Default | Description |
|----------|---------|-------------|
| `STRIPE_ENABLED` | `false` | Enable Stripe billing |
| `STRIPE_SECRET_KEY` | - | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | - | Stripe webhook secret |

### Sandbox Execution

| Variable | Default | Description |
|----------|---------|-------------|
| `SANDBOX_ENABLED` | `false` | Enable sandboxed code execution |
| `SANDBOX_DOCKER_HOST` | `unix:///var/run/docker.sock` | Docker socket path |

## Kubernetes Configuration

### Resource Limits

Default resource configuration in `values.yaml`:

```yaml
backend:
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

frontend:
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"

postgresql:
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"
```

### Autoscaling

```yaml
backend:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilization: 70
    targetMemoryUtilization: 80
```

### Persistence

```yaml
postgresql:
  persistence:
    enabled: true
    size: 50Gi
    storageClass: ""  # Use default
```

## Network Configuration

### Ingress

Configure ingress hosts in `values.yaml`:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  hosts:
    - host: app.yourdomain.com
      paths:
        - path: /
          service: frontend
    - host: api.yourdomain.com
      paths:
        - path: /
          service: backend
  tls:
    - secretName: agenthero-tls
      hosts:
        - app.yourdomain.com
        - api.yourdomain.com
```

### WebSocket Support

The ingress is configured for WebSocket support with these annotations:
```yaml
nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
```

## Security Configuration

See [Security Guide](security.md) for:
- TLS/HTTPS setup
- Network policies
- Secret management
- RBAC configuration
