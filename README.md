# NodeLoom Self-Hosted

Deploy NodeLoom on your own infrastructure. This repository contains deployment configurations and documentation for running NodeLoom in your own environment.

## Deployment Options

| Method | Best For |
|--------|----------|
| [Docker Compose](docs/docker-compose.md) | Single server, development, small teams |
| [Kubernetes](docs/kubernetes.md) | Production, high availability, scaling |
| [Helm Chart](docs/helm.md) | Kubernetes with templated configuration |

## Quick Start

### Docker Compose (Fastest)

```bash
# Clone this repository
git clone https://github.com/Nodeloom/nodeloom-self-hosted.git
cd nodeloom-self-hosted

# Copy environment template
cp .env.example .env

# Generate required secrets (copy output to .env)
echo "APP_ENCRYPTION_KEY=$(openssl rand -base64 32)"
echo "JWT_SECRET=$(openssl rand -base64 64)"
echo "APP_ADMIN_API_KEY=$(openssl rand -base64 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24)"
echo "REDIS_PASSWORD=$(openssl rand -base64 24)"

# Edit .env with:
# - Paste the generated secrets above
# - NODELOOM_LICENSE_KEY (obtain from NodeLoom)
# - ADMIN_EMAIL and ADMIN_PASSWORD (initial admin credentials)

# Start all services
docker-compose up -d

# Access NodeLoom
open http://localhost:3000

# Log in with your ADMIN_EMAIL and ADMIN_PASSWORD
# Change password via Settings → Security (recommended)
```

> **Security Note**: The application will not start without valid security secrets. Never use example/default values in production.

### Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Configure secrets (edit first!)
kubectl apply -f k8s/secrets.yaml

# Deploy all components
kubectl apply -f k8s/

# Check status
kubectl get pods -n nodeloom
```

### Helm

```bash
# Add values override
cp helm/nodeloom/values.yaml my-values.yaml
# Edit my-values.yaml with your configuration

# Install
helm install nodeloom ./helm/nodeloom \
  --namespace nodeloom \
  --create-namespace \
  -f my-values.yaml
```

## User Management

Self-hosted NodeLoom has different user management than the SaaS version:

| Feature | SaaS | Self-Hosted |
|---------|------|-------------|
| Public Registration | Yes | **Disabled** |
| Initial Admin | Self-registration | Environment variables |
| Add Users | Invite + Registration | Admin invitation or SSO |
| SSO/SAML | Enterprise feature | Fully supported |

### Initial Setup
1. Generate security secrets (see Quick Start above)
2. Configure all required values in `.env`
3. Start NodeLoom - admin user is auto-created on first boot
4. Log in with admin credentials
5. **Change password** via Settings → Security (recommended)
6. Configure OAuth providers via Admin → OAuth Providers (optional)
7. Invite additional users or configure SSO

## Security

### Required Secrets

| Secret | Purpose | Generate With |
|--------|---------|---------------|
| `APP_ENCRYPTION_KEY` | Encrypts stored credentials (AES-256-GCM) | `openssl rand -base64 32` |
| `JWT_SECRET` | Signs authentication tokens | `openssl rand -base64 64` |
| `APP_ADMIN_API_KEY` | Backoffice API authentication | `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | Database authentication | `openssl rand -base64 24` |
| `REDIS_PASSWORD` | Cache authentication | `openssl rand -base64 24` |

### Important Security Notes

- **Startup Validation**: The application will not start without valid security secrets
- **Weak Key Detection**: Keys containing "dev-", "test-", "example" are rejected in production
- **Encryption Key Persistence**: If you change `APP_ENCRYPTION_KEY`, all stored credentials become unreadable
- **Unique Keys**: Never reuse keys across environments (dev, staging, production)
- **Backup Keys**: Store your encryption key securely - it's required to decrypt credentials after restore

### Adding Users
- **Admin Invitation**: Admins can invite users via Settings → Team
- **SSO/SAML**: Configure enterprise SSO for automatic user provisioning
- **No Public Registration**: Users cannot self-register

## Requirements

### Minimum Hardware
- **CPU**: 4 cores
- **RAM**: 8 GB
- **Storage**: 50 GB SSD

### Recommended (Production)
- **CPU**: 8+ cores
- **RAM**: 16+ GB
- **Storage**: 100+ GB SSD (NVMe preferred)

### Software Requirements
- Docker 24+ and Docker Compose 2.20+ (for Docker deployment)
- Kubernetes 1.28+ (for K8s deployment)
- Helm 3.12+ (for Helm deployment)
- PostgreSQL 16 with pgvector extension
- Redis 7+

## Documentation

- [Installation Guide](docs/installation.md) - Detailed setup instructions
- [Configuration Reference](docs/configuration.md) - All configuration options
- [Backup & Restore](docs/backup-restore.md) - Data protection procedures
- [Upgrading](docs/upgrading.md) - Version upgrade procedures
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Security Hardening](docs/security.md) - Production security checklist

## Docker Images

Official images are published to GitHub Container Registry:

```
ghcr.io/nodeloom/nodeloom-backend:latest
ghcr.io/nodeloom/nodeloom-frontend:latest
```

### Available Tags
- `latest` - Most recent stable release
- `x.y.z` - Specific version (e.g., `1.0.0`)
- `main` - Latest from main branch (may be unstable)

## Support

- **Documentation**: https://docs.nodeloom.io
- **Issues**: https://github.com/Nodeloom/nodeloom-self-hosted/issues
- **Email**: support@nodeloom.io

## License

This deployment repository is provided for licensed NodeLoom customers only.
See [LICENSE](LICENSE) for terms.

Copyright 2026 NodeLoom. All rights reserved.
