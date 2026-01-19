# AgentHero Self-Hosted

Deploy AgentHero on your own infrastructure. This repository contains deployment configurations and documentation for running AgentHero in your own environment.

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
git clone https://github.com/reedzerrad/agenthero-self-hosted.git
cd agenthero-self-hosted

# Copy and configure environment
cp .env.example .env
# Edit .env with your settings (JWT secret, API keys, etc.)

# Start all services
docker-compose up -d

# Access AgentHero
open http://localhost:3000
```

### Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Configure secrets (edit first!)
kubectl apply -f k8s/secrets.yaml

# Deploy all components
kubectl apply -f k8s/

# Check status
kubectl get pods -n agenthero
```

### Helm

```bash
# Add values override
cp helm/agenthero/values.yaml my-values.yaml
# Edit my-values.yaml with your configuration

# Install
helm install agenthero ./helm/agenthero \
  --namespace agenthero \
  --create-namespace \
  -f my-values.yaml
```

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
ghcr.io/reedzerrad/agenthero-backend:latest
ghcr.io/reedzerrad/agenthero-frontend:latest
```

### Available Tags
- `latest` - Most recent stable release
- `x.y.z` - Specific version (e.g., `1.0.0`)
- `main` - Latest from main branch (may be unstable)

## Support

- **Documentation**: https://docs.agenthero.io
- **Issues**: https://github.com/reedzerrad/agenthero-self-hosted/issues
- **Email**: support@agenthero.io

## License

This deployment repository is provided for licensed AgentHero customers only.
See [LICENSE](LICENSE) for terms.

Copyright 2026 AgentHero. All rights reserved.
