#!/usr/bin/env bash
# 使い方: bash tests/run.sh [テスト関数名...]
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
source ./helpers.sh
for f in ./test_*.sh; do source "$f"; done

if [ $# -gt 0 ]; then names=("$@"); else mapfile -t names < <(declare -F | awk '{print $3}' | grep '^test_'); fi

failed=0
for n in "${names[@]}"; do
  if ( "$n"; exit "$FAILED" ); then echo "PASS $n"; else echo "FAIL $n"; failed=1; fi
done
exit "$failed"
