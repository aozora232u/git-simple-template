#!/usr/bin/env bash
# start.sh の今の動きを固定するテスト

test_start_creates_branch() {
  setup_origin
  clone_as alice; run start 12 Login
  assert_eq 0 "$RC" "rc"
  assert_eq "feature/12-login" "$(git branch --show-current)" "branch"
  git -C "$T/origin.git" show-ref -q --verify refs/heads/feature/12-login || fail "pushed"
}

test_start_rejects_non_number() {
  setup_origin
  clone_as alice; run start abc
  assert_eq 1 "$RC" "rc"; assert_contains "$OUT" "数字で入力してください" "msg"
}

test_start_returns_to_existing_and_merges_main() {
  setup_origin
  clone_as alice; run start 12 login; git switch -q main
  # seed で main に新しいコミットを足す
  (cd "$T/seed" && echo x > new.txt && git add . && git commit -qm m && git push -q)
  run start 12
  assert_eq "feature/12-login" "$(git branch --show-current)" "branch"
  assert_file new.txt
}

test_start_after_merge_moves_aside_and_carries_changes() {
  setup_origin
  clone_as alice; run start 12 login
  echo a > a.txt
  run start 12
  merge_and_delete_remote feature/12-login
  echo b > b.txt
  run start 13 next
  assert_eq 0 "$RC" "rc"
  assert_eq "feature/13-next" "$(git branch --show-current)" "branch"
  assert_eq 1 "$(git branch --list 'merged/12-login-*' | wc -l | tr -d ' ')" "merged branch"
  assert_contains "$(git log -1 --name-only)" "b.txt" "b.txt committed"
  assert_contains "$OUT" "手元の控え(merged/...)に退避しました" "msg"
}
