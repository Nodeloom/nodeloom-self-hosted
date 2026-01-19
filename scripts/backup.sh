#!/bin/bash
# NodeLoom Database Backup Script
# Usage: ./scripts/backup.sh [backup_dir]

set -e

# Configuration
BACKUP_DIR="${1:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="nodeloom_${TIMESTAMP}.sql.gz"

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

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Starting NodeLoom backup..."
log_info "Backup directory: $BACKUP_DIR"

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

# Perform backup
if [ "$DEPLOYMENT_TYPE" == "docker-compose" ]; then
    log_info "Creating PostgreSQL backup via Docker Compose..."

    docker-compose exec -T postgres pg_dump -U nodeloom nodeloom | gzip > "$BACKUP_DIR/$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        log_info "Backup created: $BACKUP_DIR/$BACKUP_FILE"
    else
        log_error "Backup failed!"
        exit 1
    fi

elif [ "$DEPLOYMENT_TYPE" == "kubernetes" ]; then
    log_info "Creating PostgreSQL backup via Kubernetes..."

    PG_POD=$(kubectl get pods -n nodeloom -l app=postgres -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$PG_POD" ]; then
        log_error "Could not find PostgreSQL pod"
        exit 1
    fi

    kubectl exec -n nodeloom "$PG_POD" -- pg_dump -U nodeloom nodeloom | gzip > "$BACKUP_DIR/$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        log_info "Backup created: $BACKUP_DIR/$BACKUP_FILE"
    else
        log_error "Backup failed!"
        exit 1
    fi
fi

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
log_info "Backup size: $BACKUP_SIZE"

# Clean up old backups
log_info "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "nodeloom_*.sql.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
if [ "$DELETED_COUNT" -gt 0 ]; then
    log_info "Deleted $DELETED_COUNT old backup(s)"
fi

# List current backups
log_info "Current backups:"
ls -lh "$BACKUP_DIR"/nodeloom_*.sql.gz 2>/dev/null || log_warn "No backups found"

log_info "Backup completed successfully!"
echo ""
echo "To restore this backup, run:"
echo "  ./scripts/restore.sh $BACKUP_DIR/$BACKUP_FILE"
