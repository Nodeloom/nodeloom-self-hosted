#!/bin/bash
set -euo pipefail

# NodeLoom Self-Hosted Updater
# Watches for update requests from the backend and orchestrates container updates.
#
# Communication:
#   Backend writes /updates/update-request.json → updater acts on it
#   Updater writes /updates/update-status.json → backend reads it
#
# This container requires:
#   - Docker socket mounted at /var/run/docker.sock
#   - Shared volume at /updates
#   - Compose file mounted at /compose/docker-compose.yml
#   - .env file mounted at /compose/.env

UPDATES_DIR="/updates"
REQUEST_FILE="${UPDATES_DIR}/update-request.json"
STATUS_FILE="${UPDATES_DIR}/update-status.json"
COMPOSE_FILE="/compose/docker-compose.yml"
ENV_FILE="/compose/.env"

REGISTRY="${REGISTRY:-ghcr.io/nodeloom}"
BACKEND_IMAGE="${REGISTRY}/nodeloom-backend-selfhosted"
FRONTEND_IMAGE="${REGISTRY}/nodeloom-frontend-selfhosted"

write_status() {
    local status="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"status\":\"${status}\",\"message\":\"${message}\",\"timestamp\":\"${timestamp}\"}" > "${STATUS_FILE}"
}

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# Ensure updates directory exists
mkdir -p "${UPDATES_DIR}"

log "NodeLoom Updater started"
log "Watching for update requests at ${REQUEST_FILE}"

write_status "IDLE" "Waiting for update requests"

while true; do
    if [ -f "${REQUEST_FILE}" ]; then
        TARGET_VERSION=$(jq -r '.targetVersion // empty' "${REQUEST_FILE}" 2>/dev/null || true)

        if [ -z "${TARGET_VERSION}" ]; then
            log "ERROR: Invalid request file — missing targetVersion"
            write_status "FAILED" "Invalid update request"
            rm -f "${REQUEST_FILE}"
            sleep 5
            continue
        fi

        # Validate version format (semver only)
        if ! echo "${TARGET_VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            log "ERROR: Invalid version format: ${TARGET_VERSION}"
            write_status "FAILED" "Invalid version format: ${TARGET_VERSION}"
            rm -f "${REQUEST_FILE}"
            sleep 5
            continue
        fi

        log "Update requested: ${TARGET_VERSION}"
        write_status "PULLING" "Pulling images for version ${TARGET_VERSION}"

        # Pull new images
        PULL_FAILED=0
        log "Pulling ${BACKEND_IMAGE}:${TARGET_VERSION}"
        if ! docker pull "${BACKEND_IMAGE}:${TARGET_VERSION}"; then
            log "ERROR: Failed to pull backend image"
            PULL_FAILED=1
        fi

        if [ "${PULL_FAILED}" -eq 0 ]; then
            log "Pulling ${FRONTEND_IMAGE}:${TARGET_VERSION}"
            if ! docker pull "${FRONTEND_IMAGE}:${TARGET_VERSION}"; then
                log "ERROR: Failed to pull frontend image"
                PULL_FAILED=1
            fi
        fi

        if [ "${PULL_FAILED}" -ne 0 ]; then
            write_status "FAILED" "Failed to pull images for version ${TARGET_VERSION}"
            rm -f "${REQUEST_FILE}"
            sleep 5
            continue
        fi

        log "Images pulled successfully"
        write_status "RESTARTING" "Restarting services with version ${TARGET_VERSION}"

        # Update .env with new version
        if [ -f "${ENV_FILE}" ]; then
            if grep -q '^NODELOOM_VERSION=' "${ENV_FILE}"; then
                sed -i "s/^NODELOOM_VERSION=.*/NODELOOM_VERSION=${TARGET_VERSION}/" "${ENV_FILE}"
            else
                echo "NODELOOM_VERSION=${TARGET_VERSION}" >> "${ENV_FILE}"
            fi

            if grep -q '^NODELOOM_FRONTEND_TAG=' "${ENV_FILE}"; then
                sed -i "s/^NODELOOM_FRONTEND_TAG=.*/NODELOOM_FRONTEND_TAG=${TARGET_VERSION}/" "${ENV_FILE}"
            else
                echo "NODELOOM_FRONTEND_TAG=${TARGET_VERSION}" >> "${ENV_FILE}"
            fi
        fi

        # Recreate backend and frontend containers with new images
        # --no-deps ensures postgres, redis, nginx are not touched
        if docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d --no-deps backend frontend 2>&1; then
            log "Services restarted successfully with version ${TARGET_VERSION}"
            write_status "COMPLETED" "Successfully updated to version ${TARGET_VERSION}"
        else
            log "ERROR: Failed to restart services"
            write_status "FAILED" "Failed to restart services for version ${TARGET_VERSION}"
        fi

        rm -f "${REQUEST_FILE}"
    fi

    sleep 5
done
