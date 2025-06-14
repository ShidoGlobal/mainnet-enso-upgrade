#!/bin/bash

set -e  # Exit on any error

# Check if the script is run as root
#if [ "$(id -u)" != "0" ]; then
#  echo "This script must be run as root or with sudo." 1>&2
#  exit 1
#fi

current_path=$(pwd)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Starting Shido upgrade process..."

# Replace cosmwasmvm with cosmwasmvm v2.1.4
print_status "Updating cosmwasmvm library..."
if [ -f "$current_path/libwasmvm.x86_64.so" ]; then
    sudo rm -rf /usr/lib/libwasmvm.x86_64.so
    sudo cp "$current_path/libwasmvm.x86_64.so" /usr/lib/
    print_status "cosmwasmvm library updated successfully"
else
    print_warning "libwasmvm.x86_64.so not found in current directory"
fi

# Get OS and version
OS=$(awk -F= '/^NAME=/{print $2}' /etc/os-release | tr -d '"' | awk '{print $1}')
VERSION=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')

print_status "Detected OS: $OS $VERSION"

# Define the binary
BINARY="shidod"

# Set dedicated home directory for the shidod instance
HOMEDIR="/data/.tmp-shidod"
print_status "Setting up daemon environment..."

# Update profile with daemon settings
echo "export DAEMON_NAME=shidod" >> ~/.profile
echo "export DAEMON_HOME=$HOMEDIR" >> ~/.profile
source ~/.profile

print_status "DAEMON_HOME is now: $HOMEDIR"
print_status "DAEMON_NAME is now: shidod"

# Check if the OS is Ubuntu and the version is either 20.04 or 22.04
if [ "$OS" = "Ubuntu" ] && { [ "$VERSION" = "20.04" ] || [ "$VERSION" = "22.04" ]; }; then
    print_status "Downloading shidod binary for Ubuntu $VERSION..."
    
    # Download the binary
    DOWNLOAD_URL="https://github.com/ShidoGlobal/mainnet-enso-upgrade/releases/download/ubuntu${VERSION}/shidod"
    print_status "Download URL: $DOWNLOAD_URL"
    
    # Remove existing binary if present
    if [ -f "$BINARY" ]; then
        rm -f "$BINARY"
    fi
    
    # Download with error checking
    if command -v wget >/dev/null 2>&1; then
        wget "$DOWNLOAD_URL" -O "$BINARY"
    elif command -v curl >/dev/null 2>&1; then
        curl -L "$DOWNLOAD_URL" -o "$BINARY"
    else
        print_error "Neither wget nor curl is installed. Please install one of them."
        exit 1
    fi
    
    # Verify download
    if [ ! -f "$BINARY" ]; then
        print_error "Failed to download binary"
        exit 1
    fi
    
    # Make the binary executable
    chmod +x "$BINARY"
    
    # Verify binary works
    if ./"$BINARY" version >/dev/null 2>&1; then
        print_status "Binary downloaded and verified successfully"
    else
        print_warning "Binary downloaded but version check failed"
    fi
    
     
    # Add upgrade with Cosmovisor (if cosmovisor is available)
    if command -v cosmovisor >/dev/null 2>&1; then
        print_status "Adding upgrade to Cosmovisor..."
        cosmovisor add-upgrade v3.1.0 "$current_path/$BINARY"
        print_status "Upgrade module 'v3.1.0' created successfully"
    else
        print_warning "Cosmovisor not found. Binary copied to upgrade directory manually."
        print_warning "You may need to configure Cosmovisor manually."
    fi
    
    
    chmod u+x $HOMEDIR/cosmovisor/upgrades/v3.1.0/bin/shidod
    print_status "Shido upgrade completed successfully!"
    print_status "Binary location: $current_path/$BINARY"
    print_status "Cosmovisor upgrade: $HOMEDIR/cosmovisor/upgrades/v3.1.0/bin/shidod"
    
else
    print_error "Unsupported OS or version: $OS $VERSION"
    print_error "Only Ubuntu 20.04 and 22.04 are supported at this time."
    exit 1
fi

print_status "Script execution completed!"