#!/usr/bin/env bash
set -euo pipefail

# Visual log formatting elements
INFO='\033[0;32m[INFO]\033[0m'
WARN='\033[0;33m[WARN]\033[0m'
ERR='\033[0;31m[ERR]\033[0m'

echo -e "${INFO} Booting Service Mesh Infrastructure Cluster..."
docker compose up -d --build

echo -e "${INFO} Allowing nodes 8 seconds to complete Erlang RPC handshakes..."
sleep 8

echo -e "${INFO} Checking Ingress Gateway registration tracking maps..."
GATEWAY_LOGS=$(docker logs mesh_gateway_node 2>&1)

if echo "$GATEWAY_LOGS" | grep -q "Dynamic node registration received"; then
    echo -e "${INFO} SUCCESS: Dynamic remote registrations caught by Gateway process!"
else
    echo -e "${WARN} WARNING: Registration signature not found in standard gateway logs. Printing output:"
    docker logs mesh_gateway_node | tail -n 15
fi

echo -e "\n${INFO} Executing Edge Mesh Traffic Route Assertions via curl..."

# Test 1: Verify parsing, slicing, and routing to Auth application node
echo -e "${INFO} Routing Request -> tenant1.auth.mesh.local:4000"
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: tenant1.auth.mesh.local:4000" http://localhost:4000/ || true)
echo -e "${INFO} Gateway HTTP Response Status: $AUTH_RESPONSE"

# Test 2: Verify programmatic internal backplane override behavior
echo -e "${INFO} Routing Request -> X-Backplane-Service Override to Chat Cluster"
CHAT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Backplane-Service: chat.mesh.local" http://localhost:4000/health || true)
echo -e "${INFO} Gateway HTTP Response Status: $CHAT_RESPONSE"

# Test 3: Simulating a node teardown/scale down to trigger process tracking pruning
echo -e "\n${INFO} Simulating elastic drop. Killing down-stream app container: auth_app_node..."
docker stop auth_app_node

echo -e "${INFO} Waiting for Gateway to trap cross-node process link exit signal..."
sleep 3

echo -e "${INFO} Inspecting gateway logs for safety pruning signatures..."
PRUNE_LOGS=$(docker logs mesh_gateway_node 2>&1)

if echo "$PRUNE_LOGS" | grep -q "pruning broken routes"; then
    echo -e "${INFO} CRITICAL SUCCESS: Fault-tolerant route pruning engine fired successfully!"
else
    echo -e "${ERR} FAILURE: Gateway failed to notice dropped node or process channel."
fi

# Clean up environment variables and active containers
echo -e "${INFO} Tearing down testing matrix..."
docker compose down
