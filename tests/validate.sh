#!/bin/bash
# =============================================================================
# NodeLoom Self-Hosted Deployment Validation Tests
# =============================================================================
# Validates all deployment configurations for consistency and correctness.
# Usage: ./tests/validate.sh
# Exit code: 0 = all pass, 1 = failures found
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Counters
PASS=0
FAIL=0
SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() {
    ((PASS++))
    echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
    ((FAIL++))
    echo -e "  ${RED}FAIL${NC} $1"
}

skip() {
    ((SKIP++))
    echo -e "  ${YELLOW}SKIP${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# =============================================================================
section "1. YAML Syntax Validation"
# =============================================================================

validate_yaml() {
    local file="$1"
    local rel="${file#$REPO_DIR/}"
    # Skip helm templates (contain Go template syntax)
    if [[ "$file" == *"/templates/"* ]]; then
        skip "$rel (Helm template — requires helm for validation)"
        return
    fi
    if python3 -c "
import yaml, sys
try:
    with open('$file') as f:
        list(yaml.safe_load_all(f))
    sys.exit(0)
except Exception as e:
    print(f'  Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
        pass "$rel"
    else
        fail "$rel — invalid YAML"
    fi
}

# Check if python yaml module is available
if python3 -c "import yaml" 2>/dev/null; then
    for f in "$REPO_DIR"/docker-compose.yml \
             "$REPO_DIR"/k8s/*.yaml \
             "$REPO_DIR"/helm/nodeloom/Chart.yaml \
             "$REPO_DIR"/helm/nodeloom/values.yaml \
             "$REPO_DIR"/helm/nodeloom/templates/*.yaml; do
        [ -f "$f" ] && validate_yaml "$f"
    done
else
    skip "YAML syntax validation (python3 yaml module not available)"
fi

# =============================================================================
section "2. Docker Compose Config Validation"
# =============================================================================

if command -v docker &>/dev/null; then
    # Create a minimal .env for validation
    TEMP_ENV=$(mktemp)
    cat > "$TEMP_ENV" <<'ENVEOF'
APP_ENCRYPTION_KEY=test-key-for-validation-only-32ch
JWT_SECRET=test-jwt-secret-for-validation-only-needs-to-be-long-enough-for-256-bits
APP_ADMIN_API_KEY=test-admin-api-key-for-validation
NODELOOM_LICENSE_KEY=NL-TEST-XXXXX-XXXXX-XXXXX
ADMIN_EMAIL=test@example.com
ADMIN_PASSWORD=TestPassword123
POSTGRES_PASSWORD=test-postgres-password
REDIS_PASSWORD=test-redis-password
ENVEOF

    if docker compose --env-file "$TEMP_ENV" -f "$REPO_DIR/docker-compose.yml" config > /dev/null 2>&1; then
        pass "docker-compose.yml validates with docker compose config"
    elif docker-compose --env-file "$TEMP_ENV" -f "$REPO_DIR/docker-compose.yml" config > /dev/null 2>&1; then
        pass "docker-compose.yml validates with docker-compose config"
    else
        fail "docker-compose.yml fails config validation"
    fi
    rm -f "$TEMP_ENV"
else
    skip "Docker Compose validation (docker not available)"
fi

# =============================================================================
section "3. Required Environment Variables — Docker Compose"
# =============================================================================

# These env vars MUST be present in docker-compose.yml backend service
REQUIRED_BACKEND_VARS=(
    # Security
    APP_ENCRYPTION_KEY
    JWT_SECRET
    ADMIN_API_KEY
    # Self-hosted
    DEPLOYMENT_MODE
    LICENSE_VALIDATION_ENABLED
    NODELOOM_LICENSE_KEY
    # LICENSE_VALIDATION_URL, cache TTL, grace period are hardcoded in the self-hosted image
    # Admin
    ADMIN_EMAIL
    ADMIN_PASSWORD
    # Database
    SPRING_DATASOURCE_URL
    SPRING_DATASOURCE_USERNAME
    SPRING_DATASOURCE_PASSWORD
    HIKARI_MAX_POOL_SIZE
    HIKARI_MIN_IDLE
    # Redis
    SPRING_DATA_REDIS_HOST
    SPRING_DATA_REDIS_PORT
    SPRING_DATA_REDIS_PASSWORD
    # URLs
    APP_BASE_URL
    APP_FRONTEND_URL
    APP_CORS_ALLOWED_ORIGINS
    FORWARD_HEADERS_STRATEGY
    # AI Providers
    OPENAI_API_KEY
    ANTHROPIC_API_KEY
    GOOGLE_AI_API_KEY
    AZURE_OPENAI_API_KEY
    AZURE_OPENAI_ENDPOINT
    # OAuth — all 12 providers
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET
    GITHUB_CLIENT_ID
    GITHUB_CLIENT_SECRET
    SLACK_CLIENT_ID
    SLACK_CLIENT_SECRET
    MICROSOFT_CLIENT_ID
    MICROSOFT_CLIENT_SECRET
    SALESFORCE_CLIENT_ID
    SALESFORCE_CLIENT_SECRET
    HUBSPOT_CLIENT_ID
    HUBSPOT_CLIENT_SECRET
    SHOPIFY_CLIENT_ID
    SHOPIFY_CLIENT_SECRET
    ZOOM_CLIENT_ID
    ZOOM_CLIENT_SECRET
    ASANA_CLIENT_ID
    ASANA_CLIENT_SECRET
    LINEAR_CLIENT_ID
    LINEAR_CLIENT_SECRET
    JIRA_CLIENT_ID
    JIRA_CLIENT_SECRET
    NOTION_CLIENT_ID
    NOTION_CLIENT_SECRET
    # CAPTCHA
    CAPTCHA_ENABLED
    CAPTCHA_SITE_KEY
    CAPTCHA_SECRET_KEY
    CAPTCHA_VERIFY_URL
    # Stripe
    STRIPE_ENABLED
    STRIPE_SECRET_KEY
    STRIPE_WEBHOOK_SECRET
    # Sandbox
    SANDBOX_ENABLED
    SANDBOX_PULL_IMAGES
    # SCIM
    SCIM_RATE_LIMIT_ENABLED
    SCIM_RATE_LIMIT_PER_MINUTE
    # Logging
    LOG_LEVEL_APP
    LOG_LEVEL_SECURITY
    LOG_LEVEL_WEB
    LOG_LEVEL_SQL
    AXIOM_TOKEN
    AXIOM_DATASET
    # Spring
    SERVER_PORT
    SPRING_PROFILES_ACTIVE
)

DC_FILE="$REPO_DIR/docker-compose.yml"
for var in "${REQUIRED_BACKEND_VARS[@]}"; do
    if grep -q "^\s*${var}:" "$DC_FILE" || grep -q "^\s*${var}=" "$DC_FILE"; then
        pass "docker-compose backend has $var"
    else
        fail "docker-compose backend MISSING $var"
    fi
done

# =============================================================================
section "4. Required Environment Variables — K8s Backend"
# =============================================================================

K8S_BACKEND="$REPO_DIR/k8s/backend.yaml"
for var in "${REQUIRED_BACKEND_VARS[@]}"; do
    # In k8s, env vars are defined as "- name: VAR_NAME"
    if grep -q "name: ${var}$" "$K8S_BACKEND" || grep -q "name: ${var}\b" "$K8S_BACKEND"; then
        pass "k8s backend has $var"
    else
        fail "k8s backend MISSING $var"
    fi
done

# =============================================================================
section "5. Required Environment Variables — Helm Backend Deployment"
# =============================================================================

HELM_BACKEND="$REPO_DIR/helm/nodeloom/templates/backend-deployment.yaml"
for var in "${REQUIRED_BACKEND_VARS[@]}"; do
    if grep -q "name: ${var}$" "$HELM_BACKEND" || grep -q "name: ${var}\b" "$HELM_BACKEND"; then
        pass "helm backend has $var"
    else
        fail "helm backend MISSING $var"
    fi
done

# =============================================================================
section "6. K8s Secrets — All Required Keys Present"
# =============================================================================

K8S_SECRETS="$REPO_DIR/k8s/secrets.yaml"
REQUIRED_SECRET_KEYS=(
    APP_ENCRYPTION_KEY
    JWT_SECRET
    APP_ADMIN_API_KEY
    POSTGRES_PASSWORD
    REDIS_PASSWORD
    NODELOOM_LICENSE_KEY
    ADMIN_EMAIL
    ADMIN_PASSWORD
    OPENAI_API_KEY
    ANTHROPIC_API_KEY
    GOOGLE_AI_API_KEY
    AZURE_OPENAI_API_KEY
    AZURE_OPENAI_ENDPOINT
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET
    GITHUB_CLIENT_ID
    GITHUB_CLIENT_SECRET
    SLACK_CLIENT_ID
    SLACK_CLIENT_SECRET
    MICROSOFT_CLIENT_ID
    MICROSOFT_CLIENT_SECRET
    SALESFORCE_CLIENT_ID
    SALESFORCE_CLIENT_SECRET
    HUBSPOT_CLIENT_ID
    HUBSPOT_CLIENT_SECRET
    SHOPIFY_CLIENT_ID
    SHOPIFY_CLIENT_SECRET
    ZOOM_CLIENT_ID
    ZOOM_CLIENT_SECRET
    ASANA_CLIENT_ID
    ASANA_CLIENT_SECRET
    LINEAR_CLIENT_ID
    LINEAR_CLIENT_SECRET
    JIRA_CLIENT_ID
    JIRA_CLIENT_SECRET
    NOTION_CLIENT_ID
    NOTION_CLIENT_SECRET
    CAPTCHA_SITE_KEY
    CAPTCHA_SECRET_KEY
    STRIPE_SECRET_KEY
    STRIPE_WEBHOOK_SECRET
    AXIOM_TOKEN
)

for key in "${REQUIRED_SECRET_KEYS[@]}"; do
    if grep -q "^\s*${key}:" "$K8S_SECRETS"; then
        pass "k8s secrets has $key"
    else
        fail "k8s secrets MISSING $key"
    fi
done

# =============================================================================
section "7. K8s ConfigMap — All Required Keys Present"
# =============================================================================

K8S_CONFIGMAP="$REPO_DIR/k8s/configmap.yaml"
REQUIRED_CONFIG_KEYS=(
    POSTGRES_DB
    POSTGRES_USER
    SPRING_PROFILES_ACTIVE
    SPRING_REDIS_HOST
    SPRING_REDIS_PORT
    DEPLOYMENT_MODE
    LICENSE_VALIDATION_ENABLED
    APP_BASE_URL
    APP_FRONTEND_URL
    APP_CORS_ALLOWED_ORIGINS
    FORWARD_HEADERS_STRATEGY
    SANDBOX_ENABLED
    SANDBOX_PULL_IMAGES
    CAPTCHA_ENABLED
    CAPTCHA_VERIFY_URL
    STRIPE_ENABLED
    SCIM_RATE_LIMIT_ENABLED
    SCIM_RATE_LIMIT_PER_MINUTE
    HIKARI_MAX_POOL_SIZE
    HIKARI_MIN_IDLE
    LOG_LEVEL_APP
    LOG_LEVEL_SECURITY
    LOG_LEVEL_WEB
    LOG_LEVEL_SQL
    AXIOM_DATASET
    # LICENSE_VALIDATION_URL, cache TTL, grace period are hardcoded in the self-hosted image
)

for key in "${REQUIRED_CONFIG_KEYS[@]}"; do
    if grep -q "^\s*${key}:" "$K8S_CONFIGMAP"; then
        pass "k8s configmap has $key"
    else
        fail "k8s configmap MISSING $key"
    fi
done

# =============================================================================
section "8. Helm values.yaml — All Required Config Keys"
# =============================================================================

HELM_VALUES="$REPO_DIR/helm/nodeloom/values.yaml"
REQUIRED_HELM_CONFIG=(
    appBaseUrl
    appFrontendUrl
    corsAllowedOrigins
    forwardHeadersStrategy
    deploymentMode
    licenseValidationEnabled
    licenseValidationUrl
    licenseCacheTtlHours
    licenseRevalidationIntervalHours
    licenseGracePeriodHours
    licenseValidationTimeoutSeconds
    captchaEnabled
    captchaVerifyUrl
    stripeEnabled
    sandboxEnabled
    sandboxPullImages
    scimRateLimitEnabled
    scimRateLimitPerMinute
    hikariMaxPoolSize
    hikariMinIdle
    logLevelApp
    logLevelSecurity
    logLevelWeb
    logLevelSql
    axiomDataset
)

for key in "${REQUIRED_HELM_CONFIG[@]}"; do
    if grep -q "^\s*${key}:" "$HELM_VALUES"; then
        pass "helm values.yaml has config.$key"
    else
        fail "helm values.yaml MISSING config.$key"
    fi
done

REQUIRED_HELM_SECRETS=(
    appEncryptionKey
    jwtSecret
    adminApiKey
    licenseKey
    adminEmail
    adminPassword
    openaiApiKey
    anthropicApiKey
    googleAiApiKey
    azureOpenaiApiKey
    azureOpenaiEndpoint
    googleClientId
    googleClientSecret
    githubClientId
    githubClientSecret
    slackClientId
    slackClientSecret
    microsoftClientId
    microsoftClientSecret
    salesforceClientId
    salesforceClientSecret
    hubspotClientId
    hubspotClientSecret
    shopifyClientId
    shopifyClientSecret
    zoomClientId
    zoomClientSecret
    asanaClientId
    asanaClientSecret
    linearClientId
    linearClientSecret
    jiraClientId
    jiraClientSecret
    notionClientId
    notionClientSecret
    captchaSiteKey
    captchaSecretKey
    stripeSecretKey
    stripeWebhookSecret
    axiomToken
)

for key in "${REQUIRED_HELM_SECRETS[@]}"; do
    if grep -q "^\s*${key}:" "$HELM_VALUES"; then
        pass "helm values.yaml has secrets.$key"
    else
        fail "helm values.yaml MISSING secrets.$key"
    fi
done

# =============================================================================
section "9. Helm secrets.yaml Template — All Keys Present"
# =============================================================================

HELM_SECRETS="$REPO_DIR/helm/nodeloom/templates/secrets.yaml"
for key in "${REQUIRED_SECRET_KEYS[@]}"; do
    if grep -q "^\s*${key}:" "$HELM_SECRETS"; then
        pass "helm secrets template has $key"
    else
        fail "helm secrets template MISSING $key"
    fi
done

# =============================================================================
section "10. .env.example — All Required Variables Documented"
# =============================================================================

ENV_EXAMPLE="$REPO_DIR/.env.example"
REQUIRED_ENV_VARS=(
    APP_ENCRYPTION_KEY
    JWT_SECRET
    APP_ADMIN_API_KEY
    NODELOOM_LICENSE_KEY
    ADMIN_EMAIL
    ADMIN_PASSWORD
    POSTGRES_PASSWORD
    REDIS_PASSWORD
    APP_BASE_URL
    APP_FRONTEND_URL
    APP_CORS_ALLOWED_ORIGINS
    FORWARD_HEADERS_STRATEGY
    OPENAI_API_KEY
    ANTHROPIC_API_KEY
    GOOGLE_AI_API_KEY
    GOOGLE_CLIENT_ID
    GITHUB_CLIENT_ID
    SLACK_CLIENT_ID
    MICROSOFT_CLIENT_ID
    SALESFORCE_CLIENT_ID
    HUBSPOT_CLIENT_ID
    SHOPIFY_CLIENT_ID
    ZOOM_CLIENT_ID
    ASANA_CLIENT_ID
    LINEAR_CLIENT_ID
    JIRA_CLIENT_ID
    NOTION_CLIENT_ID
    CAPTCHA_ENABLED
    STRIPE_ENABLED
    SANDBOX_ENABLED
    SPRING_PROFILES_ACTIVE
)

for var in "${REQUIRED_ENV_VARS[@]}"; do
    if grep -q "^${var}=" "$ENV_EXAMPLE" || grep -q "^# ${var}=" "$ENV_EXAMPLE"; then
        pass ".env.example documents $var"
    else
        fail ".env.example MISSING $var"
    fi
done

# =============================================================================
section "11. Cross-file Consistency — Docker Compose vs application.yml env vars"
# =============================================================================

# Key env vars from application.yml that Docker Compose must pass through
APP_YML_VARS=(
    APP_ENCRYPTION_KEY
    ADMIN_API_KEY
    JWT_SECRET
    HIKARI_MAX_POOL_SIZE
    HIKARI_MIN_IDLE
    FORWARD_HEADERS_STRATEGY
    APP_BASE_URL
    APP_FRONTEND_URL
    CAPTCHA_ENABLED
    CAPTCHA_SITE_KEY
    CAPTCHA_SECRET_KEY
    CAPTCHA_VERIFY_URL
    APP_CORS_ALLOWED_ORIGINS
    SCIM_RATE_LIMIT_ENABLED
    SCIM_RATE_LIMIT_PER_MINUTE
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET
    GITHUB_CLIENT_ID
    GITHUB_CLIENT_SECRET
    SLACK_CLIENT_ID
    SLACK_CLIENT_SECRET
    MICROSOFT_CLIENT_ID
    MICROSOFT_CLIENT_SECRET
    SALESFORCE_CLIENT_ID
    SALESFORCE_CLIENT_SECRET
    HUBSPOT_CLIENT_ID
    HUBSPOT_CLIENT_SECRET
    SHOPIFY_CLIENT_ID
    SHOPIFY_CLIENT_SECRET
    ZOOM_CLIENT_ID
    ZOOM_CLIENT_SECRET
    ASANA_CLIENT_ID
    ASANA_CLIENT_SECRET
    LINEAR_CLIENT_ID
    LINEAR_CLIENT_SECRET
    JIRA_CLIENT_ID
    JIRA_CLIENT_SECRET
    NOTION_CLIENT_ID
    NOTION_CLIENT_SECRET
    STRIPE_SECRET_KEY
    STRIPE_WEBHOOK_SECRET
    STRIPE_ENABLED
    DEPLOYMENT_MODE
    LICENSE_VALIDATION_ENABLED
    NODELOOM_LICENSE_KEY
    # LICENSE_VALIDATION_URL, cache TTL, grace period are hardcoded in the self-hosted image
    MACHINE_ID
    SANDBOX_ENABLED
    SANDBOX_PULL_IMAGES
    LOG_LEVEL_APP
    LOG_LEVEL_SECURITY
    LOG_LEVEL_WEB
    LOG_LEVEL_SQL
)

for var in "${APP_YML_VARS[@]}"; do
    if grep -q "${var}" "$DC_FILE"; then
        pass "docker-compose passes through $var (matches application.yml)"
    else
        fail "docker-compose MISSING $var (required by application.yml)"
    fi
done

# =============================================================================
section "12. No Stale References"
# =============================================================================

# Check for old AGENTHERO references (should be NODELOOM)
if grep -rqi "agenthero" "$REPO_DIR"/*.yml "$REPO_DIR"/*.md "$REPO_DIR"/docs/*.md "$REPO_DIR"/k8s/*.yaml "$REPO_DIR"/helm/nodeloom/values.yaml 2>/dev/null; then
    fail "Found stale 'agenthero' references (should be 'nodeloom')"
    grep -rni "agenthero" "$REPO_DIR"/*.yml "$REPO_DIR"/*.md "$REPO_DIR"/docs/*.md "$REPO_DIR"/k8s/*.yaml "$REPO_DIR"/helm/nodeloom/values.yaml 2>/dev/null | head -5
else
    pass "No stale 'agenthero' references found"
fi

# Check for old SPRING_REDIS_ (should be SPRING_DATA_REDIS_) in env var names
if grep -q "^\s*SPRING_REDIS_HOST:" "$DC_FILE" || grep -q "^\s*SPRING_REDIS_PORT:" "$DC_FILE"; then
    fail "docker-compose uses old SPRING_REDIS_ prefix (should be SPRING_DATA_REDIS_)"
else
    pass "docker-compose uses correct SPRING_DATA_REDIS_ prefix"
fi

# =============================================================================
section "13. Redis Probe Authentication"
# =============================================================================

# Redis probes must include password authentication when requirepass is set
for redis_file in "$REPO_DIR/k8s/redis.yaml" "$REPO_DIR/helm/nodeloom/templates/redis.yaml"; do
    rel="${redis_file#$REPO_DIR/}"
    if [ -f "$redis_file" ]; then
        if grep -q "REDIS_PASSWORD" "$redis_file" && grep -q "requirepass" "$redis_file"; then
            # Probes should reference the password
            if grep -A3 "livenessProbe" "$redis_file" | grep -q "REDIS_PASSWORD" || \
               grep -A5 "livenessProbe" "$redis_file" | grep -q "redis-cli -a"; then
                pass "$rel — Redis probes include authentication"
            else
                fail "$rel — Redis probes missing authentication (will fail with requirepass)"
            fi
        else
            skip "$rel — no requirepass detected"
        fi
    fi
done

# Docker compose redis healthcheck
if grep -A2 "redis-cli" "$DC_FILE" | head -5 | grep -q "REDIS_PASSWORD"; then
    pass "docker-compose redis healthcheck includes authentication"
else
    fail "docker-compose redis healthcheck missing authentication"
fi

# =============================================================================
section "14. Documentation Integrity"
# =============================================================================

# Check that all doc links in README.md point to existing files
while IFS= read -r link; do
    target="$REPO_DIR/$link"
    if [ -f "$target" ]; then
        pass "README link exists: $link"
    else
        fail "README link broken: $link"
    fi
done < <(grep -oP '\(docs/[^)]+\)' "$REPO_DIR/README.md" | tr -d '()')

# Check cross-references within docs
for doc in "$REPO_DIR"/docs/*.md; do
    rel="${doc#$REPO_DIR/}"
    while IFS= read -r link; do
        target="$REPO_DIR/docs/$link"
        if [ -f "$target" ]; then
            pass "$rel -> $link exists"
        else
            fail "$rel -> $link BROKEN"
        fi
    done < <(grep -oP '\]\([^)]*\.md\)' "$doc" | grep -oP '[^(/]+\.md' 2>/dev/null || true)
done

# =============================================================================
section "15. Security — No Hardcoded Real Secrets"
# =============================================================================

# Ensure k8s secrets.yaml uses placeholder values, not real secrets
if grep -q "CHANGE_ME" "$K8S_SECRETS"; then
    pass "k8s secrets.yaml uses CHANGE_ME placeholders"
else
    fail "k8s secrets.yaml might contain real secret values"
fi

# Ensure helm values.yaml has empty defaults for secrets
CRITICAL_SECRETS=(appEncryptionKey jwtSecret adminApiKey adminPassword)
for secret in "${CRITICAL_SECRETS[@]}"; do
    val=$(grep "^\s*${secret}:" "$HELM_VALUES" | head -1 | sed 's/.*: *//' | tr -d '"')
    if [ -z "$val" ] || [ "$val" = '""' ]; then
        pass "helm values.yaml — $secret is empty (safe default)"
    else
        fail "helm values.yaml — $secret has a non-empty default value!"
    fi
done

# =============================================================================
section "16. File Structure Validation"
# =============================================================================

REQUIRED_FILES=(
    docker-compose.yml
    .env.example
    .gitignore
    README.md
    LICENSE
    k8s/namespace.yaml
    k8s/secrets.yaml
    k8s/configmap.yaml
    k8s/backend.yaml
    k8s/frontend.yaml
    k8s/postgres.yaml
    k8s/redis.yaml
    k8s/ingress.yaml
    helm/nodeloom/Chart.yaml
    helm/nodeloom/values.yaml
    helm/nodeloom/templates/_helpers.tpl
    helm/nodeloom/templates/backend-deployment.yaml
    helm/nodeloom/templates/frontend-deployment.yaml
    helm/nodeloom/templates/secrets.yaml
    helm/nodeloom/templates/services.yaml
    helm/nodeloom/templates/postgres.yaml
    helm/nodeloom/templates/redis.yaml
    helm/nodeloom/templates/ingress.yaml
    helm/nodeloom/templates/serviceaccount.yaml
    nginx/nginx.conf
    nginx/conf.d/default.conf
    scripts/backup.sh
    scripts/restore.sh
    docs/installation.md
    docs/configuration.md
    docs/security.md
    docs/troubleshooting.md
    docs/backup-restore.md
    docs/upgrading.md
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$REPO_DIR/$f" ]; then
        pass "File exists: $f"
    else
        fail "File missing: $f"
    fi
done

# Check scripts are executable
for script in scripts/backup.sh scripts/restore.sh; do
    if [ -x "$REPO_DIR/$script" ]; then
        pass "$script is executable"
    else
        fail "$script is NOT executable"
    fi
done

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${BLUE}============================================${NC}"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "  Total:   ${TOTAL}"
echo -e "  ${GREEN}Passed:  ${PASS}${NC}"
echo -e "  ${RED}Failed:  ${FAIL}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIP}${NC}"
echo -e "${BLUE}============================================${NC}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}VALIDATION FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    exit 0
fi
