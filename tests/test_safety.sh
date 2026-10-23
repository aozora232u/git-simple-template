#!/usr/bin/env bash
# 秘密情報の検出と衝突の扱いを固定するテスト

test_secret_file_not_committed() {
  setup_origin
  (cd "$T/seed" && sed -i '/^\.env$/d' .gitignore && git commit -qam "ungitignore env" && git push -q origin main)
  clone_as alice; run start 12 login
  mkdir -p config; echo SECRET=1 > config/.env
  save_here
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "秘密情報の可能性がある" "msg"
  assert_not_contains "$(git log --all --name-only)" "config/.env" "not committed"
}

test_conflict_aborts() {
  setup_origin
  clone_as alice; run start 12 login
  echo a > a.txt; save_here
  # 同じ人が別の PC(alice2)で同じブランチを進める
  clone_as alice2; git config user.name alice; git config user.email alice@example.com
  pick feature/12-login; INPUT="$T/in" run switch
  assert_eq "feature/12-login" "$(git branch --show-current)" "alice2 on own branch"
  echo pc2 > same.txt; save_here
  cd "$T/alice" || return 1
  echo pc1 > same.txt
  save_here
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "衝突しました" "msg"
  git rev-parse -q --verify MERGE_HEAD >/dev/null && fail "MERGE_HEAD remains"
}

test_conflict_with_main_aborts() {
  setup_origin
  clone_as alice; run start 12 login
  echo alice > same.txt; save_here
  (cd "$T/seed" && echo main > same.txt && git add . && git commit -qm m && git push -q)
  save_here
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "衝突しました" "msg"
  assert_eq "alice" "$(cat same.txt)" "own content kept"
  git rev-parse -q --verify MERGE_HEAD >/dev/null && fail "MERGE_HEAD remains"
}
