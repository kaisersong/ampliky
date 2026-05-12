#!/bin/bash
set -euo pipefail
CLI="${AMPLIKY_CLI:-./ampliky}"
OUTPUT=$("$CLI" rule list 2>&1)
echo "$OUTPUT" | grep -q '"jsonrpc":"2.0"' || { echo "rule list failed"; exit 1; }
echo "OK: rule list works"
