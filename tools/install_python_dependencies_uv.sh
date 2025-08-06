#!/usr/bin/env bash
set -e

# Increase the pip timeout to handle TimeoutError (same as original)
export PIP_DEFAULT_TIMEOUT=200

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOT="$DIR"/../
cd "$ROOT"

# Install UV if not available (same as original)
if ! command -v "uv" > /dev/null 2>&1; then
  echo "installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  UV_BIN="$HOME/.local/bin"
  PATH="$UV_BIN:$PATH"
fi

echo "updating uv..."
# ok to fail, can also fail due to installing with brew (same as original)
uv self update || true

# Simple caching: skip if .venv exists and is recent
if [ -d ".venv" ] && [ -f "uv.lock" ] && [ ".venv/pyvenv.cfg" -nt "uv.lock" ]; then
    echo "Using cached Python environment (.venv is newer than uv.lock)"
else
    echo "installing python packages..."
    uv sync --frozen --all-extras
fi

# Activate environment (same as original)
source .venv/bin/activate

# Set environment variables for GitHub Actions (if in GitHub Actions)
if [ -n "$GITHUB_ENV" ]; then
    echo "VIRTUAL_ENV=$PWD/.venv" >> "$GITHUB_ENV"
    echo "$PWD/.venv/bin" >> "$GITHUB_PATH"
fi

# macOS specific configuration (same as original)
if [[ "$(uname)" == 'Darwin' ]]; then
    touch "$ROOT/.env"
    echo "# msgq doesn't work on mac" >> "$ROOT/.env"
    echo "export ZMQ=1" >> "$ROOT/.env"
    echo "export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES" >> "$ROOT/.env"
fi