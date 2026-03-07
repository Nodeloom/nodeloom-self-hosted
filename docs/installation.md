# Installation Guide

This guide covers the complete installation of NodeLoom on your own infrastructure.

## Prerequisites

### Hardware Requirements

| Environment | CPU | RAM | Storage |
|-------------|-----|-----|---------|
| Development | 2 cores | 4 GB | 20 GB |
| Small Team (1-10 users) | 4 cores | 8 GB | 50 GB |
| Production (10-100 users) | 8 cores | 16 GB | 100 GB |
| Enterprise (100+ users) | 16+ cores | 32+ GB | 500+ GB |

### Software Requirements

**Docker Compose Deployment:**
- Docker Engine 24.0+
- Docker Compose 2.20+

**Kubernetes Deployment:**
- Kubernetes 1.28+
- kubectl configured
- Helm 3.12+ (optional)
- Nginx Ingress Controller
- cert-manager (for TLS, optional)

## Installation Methods

### Method 1: Docker Compose (Recommended for Small Teams)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/reedzerrad/nodeloom-self-hosted.git
   cd nodeloom-self-hosted
   ```

2. **Create configuration:**
   ```bash
   cp .env.example .env
   ```

3. **Generate secrets:**
   ```bash
   # Generate JWT secret
   echo "JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')" >> .env

   # Generate database password
   echo "POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')" >> .env

   # Generate Redis password
   echo "REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')" >> .env
   ```

4. **Configure AI providers (optional):**
   Edit `.env` and add your API keys:
   ```
   OPENAI_API_KEY=sk-...
   ANTHROPIC_API_KEY=sk-ant-...
   ```

5. **Start services:**
   ```bash
   docker-compose up -d
   ```

6. **Verify installation:**
   ```bash
   # Check all containers are running
   docker-compose ps

   # Check backend health
   curl http://localhost:8080/actuator/health

   # Access the application
   open http://localhost:3000
   ```

### Method 2: Kubernetes (Recommended for Production)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/reedzerrad/nodeloom-self-hosted.git
   cd nodeloom-self-hosted
   ```

2. **Create namespace:**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   ```

3. **Configure secrets:**
   ```bash
   # Edit secrets with your values
   vim k8s/secrets.yaml

   # Apply secrets
   kubectl apply -f k8s/secrets.yaml
   ```

4. **Deploy components:**
   ```bash
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/postgres.yaml
   kubectl apply -f k8s/redis.yaml
   kubectl apply -f k8s/backend.yaml
   kubectl apply -f k8s/frontend.yaml
   kubectl apply -f k8s/ingress.yaml
   ```

5. **Verify deployment:**
   ```bash
   kubectl get pods -n nodeloom
   kubectl get svc -n nodeloom
   ```

### Method 3: Helm Chart

1. **Clone the repository:**
   ```bash
   git clone https://github.com/reedzerrad/nodeloom-self-hosted.git
   cd nodeloom-self-hosted
   ```

2. **Create values override:**
   ```bash
   cp helm/nodeloom/values.yaml my-values.yaml
   ```

3. **Edit configuration:**
   ```yaml
   # my-values.yaml
   secrets:
     jwtSecret: "your-256-bit-secret"

   postgresql:
     auth:
       password: "secure-postgres-password"

   redis:
     auth:
       password: "secure-redis-password"

   ingress:
     hosts:
       - host: app.yourdomain.com
         paths:
           - path: /
             service: frontend
       - host: api.yourdomain.com
         paths:
           - path: /
             service: backend
   ```

4. **Install:**
   ```bash
   helm install nodeloom ./helm/nodeloom \
     --namespace nodeloom \
     --create-namespace \
     -f my-values.yaml
   ```

5. **Verify:**
   ```bash
   helm status nodeloom -n nodeloom
   kubectl get pods -n nodeloom
   ```

## Post-Installation

### Initial Login

1. Access the application at your configured URL (default: `http://localhost:3000`)
2. Log in with the `ADMIN_EMAIL` and `ADMIN_PASSWORD` configured in your `.env` file
3. **Change your password** via Settings > Security (recommended)
4. Configure OAuth providers via Settings > OAuth Providers (optional)
5. Invite additional users via Settings > Team, or configure SSO

> **Note**: Public registration is disabled in self-hosted mode. Users are added via admin invitation or SSO/SCIM provisioning.

### Configure DNS

Point your domain to your server/load balancer:
- `app.yourdomain.com` → Frontend
- `api.yourdomain.com` → Backend

### Enable TLS/HTTPS

See [Security Guide](security.md) for TLS configuration.

## Troubleshooting

### Common Issues

**Containers not starting:**
```bash
docker-compose logs backend
docker-compose logs postgres
```

**Database connection errors:**
- Verify PostgreSQL is healthy: `docker-compose ps postgres`
- Check credentials in `.env`

**API not responding:**
- Check backend logs: `docker-compose logs backend`
- Verify JWT_SECRET is set

See [Troubleshooting Guide](troubleshooting.md) for more solutions.
