#!/bin/bash
# ============================================
# Script: 02-setup-firewall.sh
# Purpose: Configure UFW firewall for Integra node
# Run: Execute on each node as root
# ============================================

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

echo "============================================"
echo "Configuring Firewall for Integra Node"
echo "============================================"

# Reset UFW to defaults
echo "[1/4] Resetting UFW..."
ufw --force reset

# Default policies
echo "[2/4] Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important - don't lock yourself out!)
echo "[3/4] Allowing SSH..."
ufw allow 22/tcp comment 'SSH'

# Allow Integra network ports
echo "[4/4] Allowing Integra network ports..."

# P2P port - Allow from anywhere (needed for peer discovery)
ufw allow ${P2P_PORT}/tcp comment 'Integra P2P'

# RPC port - Allow from anywhere (or restrict to specific IPs)
ufw allow ${RPC_PORT}/tcp comment 'Integra RPC'

# API port
ufw allow ${API_PORT}/tcp comment 'Integra REST API'

# gRPC port
ufw allow ${GRPC_PORT}/tcp comment 'Integra gRPC'

# EVM JSON-RPC port
ufw allow ${EVM_RPC_PORT}/tcp comment 'Integra EVM JSON-RPC'

# EVM WebSocket port
ufw allow ${EVM_WS_PORT}/tcp comment 'Integra EVM WebSocket'

# Enable UFW
echo "Enabling UFW..."
ufw --force enable

# Show status
echo ""
echo "============================================"
echo "Firewall Configuration Complete"
echo "============================================"
ufw status verbose

echo ""
echo "Ports opened:"
echo "  - 22 (SSH)"
echo "  - ${P2P_PORT} (P2P)"
echo "  - ${RPC_PORT} (RPC)"
echo "  - ${API_PORT} (REST API)"
echo "  - ${GRPC_PORT} (gRPC)"
echo "  - ${EVM_RPC_PORT} (EVM JSON-RPC)"
echo "  - ${EVM_WS_PORT} (EVM WebSocket)"
echo ""

