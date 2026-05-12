#!/bin/bash
set -euo pipefail
CLI="${AMPLIKY_CLI:-./ampliky}"
OUTPUT=$("$CLI" context 2>&1)
echo "$OUTPUT" | grep -q '"screens"' || { echo "Expected 'screens' in output"; exit 1; }
echo "$OUTPUT" | grep -q '"jsonrpc":"2.0"' || { echo "Expected jsonrpc response"; exit 1; }
echo "OK: context returns screen count"
