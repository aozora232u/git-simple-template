#!/usr/bin/env bash
# switch.sh の今の動きを固定するテスト

test_switch_to_other_branch() {
  setup_origin
  clone_as bob; run start 20 bob
  clone_as alice
  printf '1\n' > "$T/in"; INPUT="$T/in" run switch
  assert_eq "feature/20-bob" "$(git branch --show-current)" "branch"
  assert_contains "$OUT" "に切り替えました" "msg"
}

test_switch_cancel() {
  setup_origin
  clone_as bob; run start 20 bob
  clone_as alice
  printf '0\n' > "$T/in"; INPUT="$T/in" run switch
  assert_eq 0 "$RC" "rc"
  assert_eq "main" "$(git branch --show-current)" "branch"
  assert_contains "$OUT" "中止しました" "msg"
}
