#!/bin/bash
set -euo pipefail
SOCKET_PATH="${HOME}/.ampliky/ampliky.sock"
if [ ! -S "$SOCKET_PATH" ]; then
    echo "SKIP: socket not found (daemon not running?)"
    exit 0
fi
RESPONSE=$(echo '{"jsonrpc":"2.0","method":"context","params":{},"id":42}' | nc -U "$SOCKET_PATH" -q 1 2>&1)
echo "$RESPONSE" | grep -q '"screens"' || { echo "Expected screens in response"; exit 1; }
echo "$RESPONSE" | grep -q '"id":42' || { echo "Expected matching id"; exit 1; }
echo "OK: socket direct works"
