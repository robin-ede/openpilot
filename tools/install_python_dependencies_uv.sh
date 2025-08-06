#!/usr/bin/env bash
set -e

# Ultra-fast Python dependencies installation using UV package manager
# Optimized for GitHub Actions native runner with caching

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

# Use cached virtual environment if available
VENV_DIR="$HOME/.venv"
if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
    echo "Using cached Python virtual environment at $VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Quick validation that the environment is functional
    if python -c "import sys; print(sys.version)" > /dev/null 2>&1; then
        echo "Cached virtual environment is valid"
        
        # Check if dependencies are up to date with lock file
        if [ -f "uv.lock" ]; then
            echo "Validating dependencies against lock file..."
            # Only sync if lock file is newer than the venv or if packages are missing
            if [ "uv.lock" -nt "$VENV_DIR/pyvenv.cfg" ] || ! uv pip list --quiet > /dev/null 2>&1; then
                echo "Dependencies need updating, running uv sync..."
                uv sync --frozen --all-extras
            else
                echo "Dependencies are up to date"
            fi
        fi
    else
        echo "Cached virtual environment is corrupted, recreating..."
        rm -rf "$VENV_DIR"
    fi
fi

# Create new virtual environment if not cached or corrupted
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating new Python virtual environment with uv..."
    uv venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    echo "Installing Python packages with uv (10-100x faster than pip)..."
    uv sync --frozen --all-extras
fi

# Ensure virtual environment is activated
source "$VENV_DIR/bin/activate"

# Set environment variables for GitHub Actions
echo "Configuring environment for GitHub Actions..."
echo "VIRTUAL_ENV=$VENV_DIR" >> "$GITHUB_ENV" || true
echo "$VENV_DIR/bin" >> "$GITHUB_PATH" || true

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