#!/bin/bash
# NodeLoom Database Restore Script
# Usage: ./scripts/restore.sh <backup_file>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ -z "$1" ]; then
    log_error "Usage: ./scripts/restore.sh <backup_file>"
    echo ""
    echo "Available backups:"
    ls -lh ./backups/nodeloom_*.sql.gz 2>/dev/null || echo "  No backups found in ./backups/"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

log_warn "⚠️  WARNING: This will OVERWRITE the current database!"
log_warn "Backup file: $BACKUP_FILE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_info "Restore cancelled."
    exit 0
fi

# Detect deployment type
if command -v docker-compose &> /dev/null && docker-compose ps &> /dev/null; then
    DEPLOYMENT_TYPE="docker-compose"
elif command -v kubectl &> /dev/null && kubectl get namespace nodeloom &> /dev/null 2>&1; then
    DEPLOYMENT_TYPE="kubernetes"
else
    log_error "Could not detect deployment type. Ensure docker-compose or kubectl is configured."
    exit 1
fi

log_info "Detected deployment type: $DEPLOYMENT_TYPE"

# Create a backup of current state before restore
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SAFETY_BACKUP="./backups/pre_restore_${TIMESTAMP}.sql.gz"
mkdir -p ./backups

log_info "Creating safety backup before restore..."

if [ "$DEPLOYMENT_TYPE" == "docker-compose" ]; then
    docker-compose exec -T postgres pg_dump -U nodeloom nodeloom | gzip > "$SAFETY_BACKUP"
    log_info "Safety backup created: $SAFETY_BACKUP"

    log_info "Stopping application services..."
    docker-compose stop backend frontend

    log_info "Restoring database..."
    gunzip -c "$BACKUP_FILE" | docker-compose exec -T postgres psql -U nodeloom nodeloom

    if [ $? -eq 0 ]; then
        log_info "Database restored successfully!"
    else
        log_error "Restore failed! You can restore the safety backup:"
        echo "  ./scripts/restore.sh $SAFETY_BACKUP"
        exit 1
    fi

    log_info "Starting application services..."
    docker-compose start backend frontend

elif [ "$DEPLOYMENT_TYPE" == "kubernetes" ]; then
    PG_POD=$(kubectl get pods -n nodeloom -l app=postgres -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$PG_POD" ]; then
        log_error "Could not find PostgreSQL pod"
        exit 1
    fi

    kubectl exec -n nodeloom "$PG_POD" -- pg_dump -U nodeloom nodeloom | gzip > "$SAFETY_BACKUP"
    log_info "Safety backup created: $SAFETY_BACKUP"

    log_info "Scaling down application..."
    kubectl scale deployment backend -n nodeloom --replicas=0
    kubectl scale deployment frontend -n nodeloom --replicas=0

    log_info "Waiting for pods to terminate..."
    sleep 10

    log_info "Restoring database..."
    gunzip -c "$BACKUP_FILE" | kubectl exec -i -n nodeloom "$PG_POD" -- psql -U nodeloom nodeloom

    if [ $? -eq 0 ]; then
        log_info "Database restored successfully!"
    else
        log_error "Restore failed! You can restore the safety backup:"
        echo "  ./scripts/restore.sh $SAFETY_BACKUP"
        exit 1
    fi

    log_info "Scaling up application..."
    kubectl scale deployment backend -n nodeloom --replicas=2
    kubectl scale deployment frontend -n nodeloom --replicas=2

    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=backend -n nodeloom --timeout=120s
fi

log_info "Restore completed successfully!"
echo ""
echo "Verify the application is working:"
if [ "$DEPLOYMENT_TYPE" == "docker-compose" ]; then
    echo "  curl http://localhost:8080/actuator/health"
else
    echo "  kubectl get pods -n nodeloom"
fi
