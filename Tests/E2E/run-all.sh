#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
for test in "$SCRIPT_DIR"/test-*.sh; do
    echo "=== $(basename "$test") ==="
    if bash "$test"; then
        ((PASS++))
        echo "PASS"
    else
        ((FAIL++))
        echo "FAIL"
    fi
    echo
done
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
