#!/usr/bin/env bash
# 秘密情報の検出と衝突の扱いを固定するテスト

test_secret_file_not_committed() {
  setup_origin
  (cd "$T/seed" && sed -i '/^\.env$/d' .gitignore && git commit -qam "ungitignore env" && git push -q origin main)
  clone_as alice; run start 12 login
  mkdir -p config; echo SECRET=1 > config/.env
  run start 12
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "秘密情報の可能性がある" "msg"
  assert_not_contains "$(git log --all --name-only)" "config/.env" "not committed"
}

test_conflict_aborts() {
  setup_origin
  clone_as alice; run start 12 login
  clone_as bob; run start 12 login
  echo bob > same.txt; run start 12
  cd "$T/alice" || return 1
  echo alice > same.txt
  run start 12
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "衝突しました" "msg"
  git rev-parse -q --verify MERGE_HEAD >/dev/null && fail "MERGE_HEAD remains"
}
