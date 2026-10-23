#!/usr/bin/env bash
# reset.sh の今の動きを固定するテスト

test_reset_backs_up_and_returns_main() {
  setup_origin
  clone_as alice; run start 12 login
  echo edited > PR.md; echo n > new.txt
  printf 'y\n' > "$T/in"; INPUT="$T/in" run reset
  assert_eq "main" "$(git branch --show-current)" "branch"
  assert_eq "" "$(git status --porcelain)" "clean"
  local d; d=$(cat "$T/dir.txt")
  assert_file "$d/PR.md"
  assert_file "$d/new.txt"
}

test_reset_cancel() {
  setup_origin
  clone_as alice; run start 12 login
  echo n > new.txt
  printf 'n\n' > "$T/in"; INPUT="$T/in" run reset
  assert_contains "$OUT" "中止しました" "msg"
  assert_file new.txt
}

test_reset_japanese_filename() {
  setup_origin
  clone_as alice; run start 12 login
  echo m > "メモ 1.txt"
  printf 'y\n' > "$T/in"; INPUT="$T/in" run reset
  assert_file "$(cat "$T/dir.txt")/メモ 1.txt"
}
