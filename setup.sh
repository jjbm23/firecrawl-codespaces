#!/usr/bin/env bash
set -euo pipefail

FIRECRAWL_DIR="/workspaces/firecrawl"
FIRECRAWL_PORT=3663
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=== Firecrawl Codespace Setup ==="
echo ""

bash "$SCRIPT_DIR/prepare-docker.sh"

# --- Step 1: Clone Firecrawl ---
if [ ! -d "$FIRECRAWL_DIR" ]; then
    echo "[1/4] Cloning Firecrawl..."
    git clone --depth 1 https://github.com/mendableai/firecrawl.git "$FIRECRAWL_DIR"
else
    echo "[1/4] Firecrawl already cloned — skipping."
fi

cd "$FIRECRAWL_DIR"

# --- Step 2: Create .env ---
if [ ! -f .env ]; then
    echo "[2/4] Creating .env (port ${FIRECRAWL_PORT}, no API keys)..."
    BULL_KEY=$(openssl rand -hex 16 2>/dev/null || echo "local-dev-key-change-me")
    cat > .env << EOF
PORT=${FIRECRAWL_PORT}
HOST=0.0.0.0
USE_DB_AUTHENTICATION=false
BULL_AUTH_KEY=${BULL_KEY}
EOF
else
    echo "[2/4] .env already exists — skipping."
fi

# --- Step 3: Copy docker-compose.override.yaml (pre-built images) ---
# Always overwrite — ensures updates to image names propagate on re-run.
if [ -f "$SCRIPT_DIR/docker-compose.override.yaml" ]; then
    echo "[3/4] Copying docker-compose.override.yaml (pre-built images)..."
    cp "$SCRIPT_DIR/docker-compose.override.yaml" .
else
    echo "[3/4] No override file found — will build from source (slower first run)."
fi

# --- Step 4: Start Firecrawl ---
echo "[4/4] Starting Firecrawl..."

# Pull pre-built images if available, otherwise Docker Compose builds from source
docker compose pull 2>/dev/null || echo "  Pre-built images not found — building from source (this may take a few minutes)..."
docker compose up -d

# --- Health check ---
echo ""
echo "Waiting for Firecrawl to be ready..."

READY=false
for i in $(seq 1 60); do
    if curl -sf "http://localhost:${FIRECRAWL_PORT}/v0/health/liveness" > /dev/null 2>&1; then
        READY=true
        break
    fi
    sleep 2
done

echo ""
if [ "$READY" = true ]; then
    echo "Firecrawl is running at http://localhost:${FIRECRAWL_PORT}"
    echo ""
    echo "=== Next: Connect from your local machine ==="
    echo ""
    echo "  1. Find your Codespace name:"
    echo "     gh codespace list"
    echo ""
    echo "  2. Forward the port to localhost:"
    echo "     gh codespace ports forward ${FIRECRAWL_PORT}:${FIRECRAWL_PORT} -c <codespace-name>"
    echo ""
    echo "  3. Firecrawl is now at http://localhost:${FIRECRAWL_PORT} on your machine."
    echo "     Add this to your CLAUDE.md to use it with Claude Code."
    echo ""
else
    echo "Firecrawl didn't respond within 2 minutes."
    echo "The services may still be starting — check logs:"
    echo "  cd ${FIRECRAWL_DIR} && docker compose logs"
    echo ""
fi
