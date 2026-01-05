#!/bin/bash
# ============================================
# Script: build-binary.sh
# Purpose: Build the intgd binary for Linux deployment
# Run: Execute on your LOCAL machine
# ============================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
BUILD_DIR="${PROJECT_ROOT}/build"

echo "============================================"
echo "Building Integra Network Binary"
echo "============================================"
echo ""

cd "${PROJECT_ROOT}"

# Create build directory
mkdir -p "${BUILD_DIR}"

echo "[1/3] Building for Linux AMD64..."

# Build for Linux (target servers)
cd integra
GOOS=linux GOARCH=amd64 CGO_ENABLED=1 go build \
    -tags "netgo" \
    -ldflags "-w -s -X github.com/cosmos/cosmos-sdk/version.Name=integra \
              -X github.com/cosmos/cosmos-sdk/version.AppName=intgd \
              -X github.com/cosmos/cosmos-sdk/version.Version=$(git describe --tags --always 2>/dev/null || echo 'dev') \
              -X github.com/cosmos/cosmos-sdk/version.Commit=$(git log -1 --format='%H' 2>/dev/null || echo 'unknown')" \
    -o "${BUILD_DIR}/intgd" \
    ./cmd/intgd

echo "[2/3] Verifying binary..."
file "${BUILD_DIR}/intgd"

echo "[3/3] Getting binary info..."
"${BUILD_DIR}/intgd" version --long 2>/dev/null || echo "Binary built successfully (version check may require CGO)"

echo ""
echo "============================================"
echo "Build Complete!"
echo "============================================"
echo ""
echo "Binary location: ${BUILD_DIR}/intgd"
echo "Binary size: $(du -h "${BUILD_DIR}/intgd" | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Run 03-init-genesis.sh to initialize the network"
echo "2. Run 04-configure-nodes.sh to configure nodes"
echo "3. Run 05-deploy-to-servers.sh to deploy"
echo ""

