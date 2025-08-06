#!/usr/bin/env bash
set -e

# Ultra-fast Python dependencies installation using UV package manager
# Optimized for GitHub Actions native runner with caching

# Increase the pip timeout to handle TimeoutError (same as original)
export PIP_DEFAULT_TIMEOUT=200

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOT="$DIR"/../
cd "$ROOT"

echo "Starting optimized Python environment setup..."

# Install UV if not available (ultra-fast Python package manager)
if ! command -v "uv" > /dev/null 2>&1; then
  echo "Installing uv (ultra-fast Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  UV_BIN="$HOME/.local/bin"
  export PATH="$UV_BIN:$PATH"
fi

echo "Updating uv to latest version..."
# Update UV to latest version (can fail on some systems)
uv self update 2>/dev/null || echo "uv self update failed, continuing with current version"

# Use .venv in project directory (same as original)
VENV_DIR=".venv"

# Simple cache check - if .venv exists and is recent, try to reuse it
if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
    echo "Found existing virtual environment, checking if usable..."
    
    # Simple validation - can we activate and run python?
    if source "$VENV_DIR/bin/activate" && python -c "import sys" > /dev/null 2>&1; then
        # Check if we need to update (lock file newer than venv)
        if [ -f "uv.lock" ] && [ "uv.lock" -nt "$VENV_DIR/pyvenv.cfg" ]; then
            echo "Dependencies need updating, running uv sync..."
            uv sync --frozen --all-extras
        else
            echo "Using cached virtual environment"
        fi
    else
        echo "Cached virtual environment is corrupted, recreating..."
        rm -rf "$VENV_DIR"
    fi
fi

# Create new virtual environment if needed (following original pattern)
if [ ! -d "$VENV_DIR" ]; then
    echo "Installing python packages with uv..."
    uv sync --frozen --all-extras
fi

# Activate the environment (same as original)
source "$VENV_DIR/bin/activate"

# Set environment variables for GitHub Actions
echo "Configuring environment for GitHub Actions..."
echo "VIRTUAL_ENV=$PWD/$VENV_DIR" >> "$GITHUB_ENV" || true
echo "$PWD/$VENV_DIR/bin" >> "$GITHUB_PATH" || true

# macOS specific configuration (if needed)
if [[ "$(uname)" == 'Darwin' ]]; then
    touch "$ROOT/.env"
    echo "# msgq doesn't work on mac" >> "$ROOT/.env"
    echo "export ZMQ=1" >> "$ROOT/.env"
    echo "export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES" >> "$ROOT/.env"
fi

# Verify installation
echo "Verifying Python environment..."
python --version
pip --version
echo "Python packages installed: $(pip list --format=freeze | wc -l)"

echo "Python environment setup completed successfully!"
echo "Virtual environment: $VENV_DIR"
echo "Python executable: $(which python)"