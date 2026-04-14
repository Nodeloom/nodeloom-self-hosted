# Configuration Reference

Complete reference for all NodeLoom configuration options.

## Environment Variables

### Required Security Secrets

| Variable | Description | Generate With |
|----------|-------------|---------------|
| `APP_ENCRYPTION_KEY` | Encrypts stored credentials (AES-256-GCM). **If changed, all stored credentials become unreadable!** | `openssl rand -base64 32` |
| `JWT_SECRET` | Signs authentication tokens (min 256 bits) | `openssl rand -base64 64` |
| `APP_ADMIN_API_KEY` | Backoffice API authentication | `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | Database authentication | `openssl rand -base64 24` |
| `REDIS_PASSWORD` | Cache authentication | `openssl rand -base64 24` |

### Required Self-Hosted Configuration

| Variable | Description |
|----------|-------------|
| `NODELOOM_LICENSE_KEY` | License key (obtain from NodeLoom) |
| `ADMIN_EMAIL` | Initial admin user email (first startup only) |
| `ADMIN_PASSWORD` | Initial admin user password (first startup only) |

### Application URLs

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_BASE_URL` | `http://localhost:8080` | Backend URL for widgets, SCIM, OAuth callbacks, webhooks |
| `APP_FRONTEND_URL` | `http://localhost:3000` | Frontend URL for email links, Stripe redirects, password reset |
| `PUBLIC_API_URL` | `http://localhost:8080` | Public URL for API (used by frontend) |
| `APP_CORS_ALLOWED_ORIGINS` | `http://localhost:3000` | Comma-separated allowed CORS origins (must include frontend domain) |

> **Important**: `APP_BASE_URL` and `APP_FRONTEND_URL` must be set to your actual domains in production. Email links, OAuth callbacks, and webhook URLs will be broken if these are wrong.

### Proxy / Network

| Variable | Default | Description |
|----------|---------|-------------|
| `FORWARD_HEADERS_STRATEGY` | `NATIVE` (self-hosted) | How to handle proxy headers. Set to `NATIVE` when behind nginx, ALB, or any reverse proxy. Set to `NONE` for direct access. |

### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `nodeloom` | Database name |
| `POSTGRES_USER` | `nodeloom` | Database user |
| `POSTGRES_PASSWORD` | - | Database password (required) |
| `POSTGRES_PORT` | `5432` | PostgreSQL port |
| `HIKARI_MAX_POOL_SIZE` | `20` | Maximum database connections |
| `HIKARI_MIN_IDLE` | `5` | Minimum idle connections |

### Redis Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PASSWORD` | - | Redis password (required) |
| `REDIS_PORT` | `6379` | Redis port |

### Application Ports

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_PORT` | `8080` | Backend API port |
| `FRONTEND_PORT` | `3000` | Frontend port |

### AI Provider Configuration

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key for GPT models |
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude models |
| `GOOGLE_AI_API_KEY` | Google AI API key for Gemini models |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI API key |
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI endpoint URL |

### OAuth Configuration

NodeLoom supports 12 OAuth providers for one-click credential connections. Configure via environment variables or via **Settings > OAuth Providers** in the UI (database configuration takes precedence over env vars).

| Provider | Client ID Variable | Client Secret Variable |
|----------|-------------------|----------------------|
| Google (Gmail, Sheets, Drive, Calendar, Docs) | `GOOGLE_CLIENT_ID` | `GOOGLE_CLIENT_SECRET` |
| GitHub | `GITHUB_CLIENT_ID` | `GITHUB_CLIENT_SECRET` |
| Slack | `SLACK_CLIENT_ID` | `SLACK_CLIENT_SECRET` |
| Microsoft (Outlook, Teams, OneDrive, SharePoint) | `MICROSOFT_CLIENT_ID` | `MICROSOFT_CLIENT_SECRET` |
| Salesforce | `SALESFORCE_CLIENT_ID` | `SALESFORCE_CLIENT_SECRET` |
| HubSpot | `HUBSPOT_CLIENT_ID` | `HUBSPOT_CLIENT_SECRET` |
| Shopify | `SHOPIFY_CLIENT_ID` | `SHOPIFY_CLIENT_SECRET` |
| Zoom | `ZOOM_CLIENT_ID` | `ZOOM_CLIENT_SECRET` |
| Asana | `ASANA_CLIENT_ID` | `ASANA_CLIENT_SECRET` |
| Linear | `LINEAR_CLIENT_ID` | `LINEAR_CLIENT_SECRET` |
| Jira | `JIRA_CLIENT_ID` | `JIRA_CLIENT_SECRET` |
| Notion | `NOTION_CLIENT_ID` | `NOTION_CLIENT_SECRET` |

> **Tip**: For self-hosted deployments, you can configure OAuth providers via the admin UI at **Settings > OAuth Providers** instead of using environment variables. This allows adding/changing providers without restarting.

### CAPTCHA Configuration (Cloudflare Turnstile)

| Variable | Default | Description |
|----------|---------|-------------|
| `CAPTCHA_ENABLED` | `false` | Enable CAPTCHA on registration |
| `CAPTCHA_SITE_KEY` | - | Cloudflare Turnstile site key |
| `CAPTCHA_SECRET_KEY` | - | Cloudflare Turnstile secret key |
| `CAPTCHA_VERIFY_URL` | Turnstile URL | CAPTCHA verification endpoint |

### Stripe Configuration (Billing)

| Variable | Default | Description |
|----------|---------|-------------|
| `STRIPE_ENABLED` | `false` | Enable Stripe billing |
| `STRIPE_SECRET_KEY` | - | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | - | Stripe webhook secret |

### Sandbox Execution

| Variable | Default | Description |
|----------|---------|-------------|
| `SANDBOX_ENABLED` | `false` | Enable sandboxed code execution in Docker containers |
| `SANDBOX_DOCKER_HOST` | `unix:///var/run/docker.sock` | Docker socket path |
| `SANDBOX_PULL_IMAGES` | `true` | Auto-pull Docker images for sandbox |

### SCIM Rate Limiting

| Variable | Default | Description |
|----------|---------|-------------|
| `SCIM_RATE_LIMIT_ENABLED` | `true` | Enable rate limiting for SCIM 2.0 endpoints |
| `SCIM_RATE_LIMIT_PER_MINUTE` | `60` | Maximum SCIM requests per minute per team |

### License Settings (Advanced)

| Variable | Default | Description |
|----------|---------|-------------|
| `LICENSE_VALIDATION_URL` | NodeLoom server | License validation endpoint |
| `LICENSE_CACHE_TTL_HOURS` | `24` | How long to cache license validation results |
| `LICENSE_REVALIDATION_INTERVAL_HOURS` | `6` | How often to re-validate the license |
| `LICENSE_GRACE_PERIOD_HOURS` | `72` | Offline grace period before license enforcement |
| `LICENSE_VALIDATION_TIMEOUT_SECONDS` | `30` | Timeout for license validation requests |
| `MACHINE_ID` | auto-generated | Machine identifier for license binding |

### Logging Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL_APP` | `INFO` | Application log level |
| `LOG_LEVEL_SECURITY` | `WARN` | Spring Security log level |
| `LOG_LEVEL_WEB` | `WARN` | Spring Web/HTTP log level |
| `LOG_LEVEL_SQL` | `WARN` | Hibernate SQL log level |
| `AXIOM_TOKEN` | - | Axiom API token for cloud log shipping (no-ops when unset) |
| `AXIOM_DATASET` | `nodeloom-production` | Axiom dataset name |

> **Axiom Integration**: Set `AXIOM_TOKEN` and `AXIOM_DATASET` to ship logs to [Axiom](https://axiom.co) for cloud-based log aggregation. When not configured, logs go to stdout only.

### Memory Limits (Docker Compose)

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_MEMORY_LIMIT` | `4G` | Backend container memory limit |
| `FRONTEND_MEMORY_LIMIT` | `512M` | Frontend container memory limit |
| `POSTGRES_MEMORY_LIMIT` | `4G` | PostgreSQL container memory limit |
| `REDIS_MEMORY_LIMIT` | `1G` | Redis container memory limit |

### Agent Discovery

Agent Discovery automatically finds AI agents across your infrastructure through 6 channels:

| Source | What It Discovers | Configuration |
|--------|-------------------|---------------|
| SDK Telemetry | Agents instrumented with NodeLoom SDKs | Automatic (no config needed) |
| AWS Bedrock | Bedrock agents and foundation models | UI: Agent Inventory → Integrations |
| Azure AI | Azure OpenAI deployments and models | UI: Agent Inventory → Integrations |
| GCP Vertex AI | Vertex AI endpoints and models | UI: Agent Inventory → Integrations |
| GitHub | Repositories using AI frameworks | UI: Agent Inventory → Integrations |
| Anthropic Managed Agents | Managed Agents, models, tools, MCP servers | UI: Agent Inventory → Integrations |

All discovery source credentials are stored encrypted in the database. No environment variables are required.

**Optional:** To override the Anthropic API base URL (e.g., for a proxy):

```bash
APP_ANTHROPIC_API_BASE=https://api.anthropic.com  # default
```

Agent risk scores are auto-calculated hourly and on every agent registration/update.

### SIEM Export

Export audit logs to external SIEM systems. Configured through the UI at **Audit → SIEM Export**.

Supported targets:
- **Splunk** (HEC endpoint)
- **Datadog** (Logs API)
- **Elasticsearch** (Bulk API)
- **Custom Webhook** (any HTTP endpoint)

No environment variables are required — all configuration (URLs, tokens, auth) is stored encrypted in the database.

### SSRF Protection

SSRF (Server-Side Request Forgery) protection validates outbound HTTP requests to block private, loopback, and cloud metadata IP addresses. Enabled by default.

```bash
APP_SSRF_PROTECTION_ENABLED=true  # default; set to false only for local development
```

**Do not disable in production.** This protects against attacks targeting internal services via SIEM export URLs, webhook endpoints, and OAuth callbacks.

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
    - secretName: nodeloom-tls
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
- Encryption key management
