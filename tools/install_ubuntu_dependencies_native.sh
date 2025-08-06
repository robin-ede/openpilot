#!/usr/bin/env bash
set -e

# Ultra-fast APT setup with caching for GitHub Actions native runner
# Optimized for Ubuntu 22.04 runner environment

SUDO=""
CACHE_DIR="$HOME/.apt-cache"

# Use sudo if not root
if [[ ! $(id -u) -eq 0 ]]; then
  if [[ -z $(which sudo) ]]; then
    echo "Please install sudo or run as root"
    exit 1
  fi
  SUDO="sudo"
fi

echo "Setting up optimized APT caching..."
mkdir -p "$CACHE_DIR"

# Restore cached APT packages if they exist
if [ -d "$CACHE_DIR/archives" ] && [ "$(ls -A $CACHE_DIR/archives)" ]; then
    echo "Restoring APT package cache..."
    $SUDO mkdir -p /var/cache/apt/archives
    $SUDO cp -r "$CACHE_DIR/archives"/* /var/cache/apt/archives/ 2>/dev/null || true
fi

# Speed up APT with optimized settings
echo "Configuring APT for maximum speed..."
cat << 'EOF' | $SUDO tee /etc/apt/apt.conf.d/99openpilot-speedup > /dev/null
Acquire::Languages "none";
Acquire::GzipIndexes "true";
Acquire::CompressionTypes::Order:: "gz";
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
DPkg::Use-Pty "0";
Quiet "1";
EOF

# Try to install apt-fast for parallel downloads
echo "Installing apt-fast for parallel downloads..."
$SUDO add-apt-repository -y ppa:apt-fast/stable 2>/dev/null || echo "apt-fast PPA already added or unavailable"
$SUDO apt-get update -qq 2>/dev/null || true

# Install apt-fast if available, otherwise use regular apt
if $SUDO apt-get install -y apt-fast 2>/dev/null; then
    echo "Configuring apt-fast for maximum speed..."
    echo 'MIRRORS=( "http://archive.ubuntu.com/ubuntu,http://us.archive.ubuntu.com/ubuntu,http://ca.archive.ubuntu.com/ubuntu" )' | $SUDO tee -a /etc/apt-fast.conf > /dev/null
    echo 'MAXCONPERSRV=16' | $SUDO tee -a /etc/apt-fast.conf > /dev/null
    echo 'SPLITCON=8' | $SUDO tee -a /etc/apt-fast.conf > /dev/null
    APT_CMD="apt-fast"
else
    echo "Using regular apt (apt-fast not available)"
    APT_CMD="apt-get"
fi

# Install common packages (adapted from install_ubuntu_dependencies.sh)
echo "Installing Ubuntu dependencies..."
$SUDO $APT_CMD install -y --no-install-recommends \
    ca-certificates \
    clang \
    build-essential \
    gcc-arm-none-eabi \
    liblzma-dev \
    capnproto \
    libcapnp-dev \
    curl \
    libcurl4-openssl-dev \
    git \
    git-lfs \
    ffmpeg \
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libavfilter-dev \
    libbz2-dev \
    libeigen3-dev \
    libffi-dev \
    libglew-dev \
    libgles2-mesa-dev \
    libglfw3-dev \
    libglib2.0-0 \
    libjpeg-dev \
    libqt5charts5-dev \
    libncurses5-dev \
    libssl-dev \
    libusb-1.0-0-dev \
    libzmq3-dev \
    libzstd-dev \
    libsqlite3-dev \
    libsystemd-dev \
    locales \
    opencl-headers \
    ocl-icd-libopencl1 \
    ocl-icd-opencl-dev \
    portaudio19-dev \
    qttools5-dev-tools \
    libqt5svg5-dev \
    libqt5serialbus5-dev \
    libqt5x11extras5-dev \
    libqt5opengl5-dev \
    xvfb \
    g++-12 \
    qtbase5-dev \
    qtchooser \
    qt5-qmake \
    qtbase5-dev-tools \
    python3-dev \
    python3-venv \
    ccache

# Additional packages that are already in the runner or needed for optimization
$SUDO $APT_CMD install -y --no-install-recommends \
    sudo \
    tzdata \
    ssh \
    pulseaudio \
    x11-xserver-utils \
    gnome-screenshot \
    python3-tk

echo "Setting up OpenCL Intel runtime..."
# Simplified OpenCL setup for CI (lightweight version)
if [ ! -f "/etc/OpenCL/vendors/intel_expcpu.icd" ]; then
    $SUDO mkdir -p /etc/OpenCL/vendors
    # Use system OpenCL if available, otherwise skip for now
    if [ -f "/usr/lib/x86_64-linux-gnu/libOpenCL.so" ]; then
        echo "/usr/lib/x86_64-linux-gnu/libOpenCL.so" | $SUDO tee /etc/OpenCL/vendors/system.icd > /dev/null
    fi
fi

# Setup locale
echo "Setting up locale..."
$SUDO sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
$SUDO locale-gen 2>/dev/null || true

# Setup udev rules if directory exists
if [[ -d "/etc/udev/rules.d/" ]]; then
    echo "Setting up udev rules..."
    # Setup jungle udev rules
    $SUDO tee /etc/udev/rules.d/12-panda_jungle.rules > /dev/null <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddcf", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddef", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddcf", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddef", MODE="0666"
EOF

    # Setup panda udev rules
    $SUDO tee /etc/udev/rules.d/11-panda.rules > /dev/null <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddcc", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="3801", ATTRS{idProduct}=="ddee", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddcc", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="bbaa", ATTRS{idProduct}=="ddee", MODE="0666"
EOF

    $SUDO udevadm control --reload-rules && $SUDO udevadm trigger 2>/dev/null || true
fi

echo "Caching APT packages for next run..."
# Cache APT packages for next run
if [ -d "/var/cache/apt/archives" ]; then
    mkdir -p "$CACHE_DIR"
    cp -r /var/cache/apt/archives "$CACHE_DIR/" 2>/dev/null || true
fi

# Setup ccache
echo "Configuring ccache..."
mkdir -p ~/.ccache
ccache -M 2G 2>/dev/null || true

echo "Ubuntu dependencies installation completed successfully!"