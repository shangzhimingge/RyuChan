#!/bin/bash
set -euo pipefail

# =============================================
# RyuChan Docker Deploy — clone from GitHub & run
# Usage: ./deploy.sh [--run]
# =============================================

REPO_URL="${REPO_URL:-https://github.com/shangzhimingge/RyuChan.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
PROJECT_DIR="${PROJECT_DIR:-/opt/ryuchan}"
IMAGE_NAME="${IMAGE_NAME:-ryuchan}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-ryuchan}"
PORT="${PORT:-3575}"

# --- clone or pull ---
if [ -d "${PROJECT_DIR}/.git" ]; then
  echo "==> Pulling ${REPO_BRANCH} ..."
  cd "${PROJECT_DIR}"
  git fetch origin "${REPO_BRANCH}"
  git reset --hard "origin/${REPO_BRANCH}"
else
  echo "==> Cloning ${REPO_URL} ..."
  git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${PROJECT_DIR}"
  cd "${PROJECT_DIR}"
fi

# --- load .env if exists ---
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# --- build ---
echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} ..."
docker build \
  --no-cache \
  --build-arg PUBLIC_GITHUB_OWNER="${PUBLIC_GITHUB_OWNER:-}" \
  --build-arg PUBLIC_GITHUB_REPO="${PUBLIC_GITHUB_REPO:-}" \
  --build-arg PUBLIC_GITHUB_BRANCH="${PUBLIC_GITHUB_BRANCH:-}" \
  --build-arg PUBLIC_GITHUB_APP_ID="${PUBLIC_GITHUB_APP_ID:-}" \
  --build-arg PUBLIC_GITHUB_ENCRYPT_KEY="${PUBLIC_GITHUB_ENCRYPT_KEY:-}" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

echo "==> Done. Image: ${IMAGE_NAME}:${IMAGE_TAG}"

# --- run ---
if [ "${1:-}" = "--run" ]; then
  docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

  echo "==> Starting container ${CONTAINER_NAME} on port ${PORT} ..."
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${PORT}:80" \
    "${IMAGE_NAME}:${IMAGE_TAG}"

  echo "==> Running at http://0.0.0.0:${PORT}"

  echo "==> Health check..."
  for i in $(seq 1 30); do
    if curl -sf -o /dev/null "http://localhost:${PORT}/"; then
      echo "==> Health OK"
      exit 0
    fi
    sleep 1
  done
  echo "==> WARN: Health check timeout"
fi
