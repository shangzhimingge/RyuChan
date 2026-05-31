#!/bin/bash
set -euo pipefail

# =============================================
# RyuChan Auto-Poll — check GitHub & redeploy on change
# Usage: ./watch.sh
# Cron:  */5 * * * * /opt/ryuchan/scripts/watch.sh >> /var/log/ryuchan-watch.log 2>&1
# =============================================

REPO_URL="${REPO_URL:-https://github.com/shangzhimingge/RyuChan.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
PROJECT_DIR="${PROJECT_DIR:-/opt/ryuchan}"
CACHE_FILE="${PROJECT_DIR}/.last_sync_sha"

cd "${PROJECT_DIR}"

# Get remote HEAD SHA
REMOTE_SHA=$(git ls-remote "${REPO_URL}" "refs/heads/${REPO_BRANCH}" | awk '{print $1}')
if [ -z "${REMOTE_SHA}" ]; then
    echo "[$(date -Iseconds)] ERROR: cannot fetch remote SHA"
    exit 1
fi

# Compare with cached SHA
if [ -f "${CACHE_FILE}" ]; then
    CACHED_SHA=$(cat "${CACHE_FILE}")
    if [ "${REMOTE_SHA}" = "${CACHED_SHA}" ]; then
        exit 0  # No changes
    fi
fi

echo "[$(date -Iseconds)] New commit detected: ${REMOTE_SHA}"

# Pull & rebuild
git fetch origin "${REPO_BRANCH}"
git reset --hard "origin/${REPO_BRANCH}"

# Load .env
if [ -f .env ]; then
    set -a; source .env; set +a
fi

docker build \
    --no-cache \
    --build-arg PUBLIC_GITHUB_OWNER="${PUBLIC_GITHUB_OWNER:-}" \
    --build-arg PUBLIC_GITHUB_REPO="${PUBLIC_GITHUB_REPO:-}" \
    --build-arg PUBLIC_GITHUB_BRANCH="${PUBLIC_GITHUB_BRANCH:-}" \
    --build-arg PUBLIC_GITHUB_APP_ID="${PUBLIC_GITHUB_APP_ID:-}" \
    --build-arg PUBLIC_GITHUB_ENCRYPT_KEY="${PUBLIC_GITHUB_ENCRYPT_KEY:-}" \
    -t "ryuchan:latest" .

docker rm -f ryuchan 2>/dev/null || true
docker run -d \
    --name ryuchan \
    --restart unless-stopped \
    -p "${PORT:-3575}:80" \
    ryuchan:latest

echo "${REMOTE_SHA}" > "${CACHE_FILE}"
echo "[$(date -Iseconds)] Deploy OK — http://0.0.0.0:${PORT:-3575}"
