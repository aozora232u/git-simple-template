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

test_start_existing_branch_stops() {
  setup_origin
  clone_as alice; run start 12 login; git switch -q main
  run start 12 login
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "既にあります" "msg"
  assert_eq "main" "$(git branch --show-current)" "branch unchanged"
}

test_start_after_merge_moves_aside_and_carries_changes() {
  setup_origin
  clone_as alice; run start 12 login
  echo a > a.txt
  save_here
  merge_and_delete_remote feature/12-login
  echo b > b.txt
  run start 13 next
  assert_eq 0 "$RC" "rc"
  assert_eq "feature/13-next" "$(git branch --show-current)" "branch"
  assert_eq 1 "$(git branch --list 'merged/12-login-*' | wc -l | tr -d ' ')" "merged branch"
  assert_contains "$(git log -1 --name-only)" "b.txt" "b.txt committed"
  assert_contains "$OUT" "手元の控え(merged/...)に退避しました" "msg"
}

test_start_retires_all_merged_branches() {
  setup_origin
  clone_as alice; run start 12 a
  echo a > a.txt
  run start 13 b                      # 12 の変更を記録してから 13 を作る
  echo b > b.txt
  save_here
  assert_eq "feature/13-b" "$(git branch --show-current)" "on 13"
  merge_and_delete_remote feature/12-a
  merge_and_delete_remote feature/13-b
  run start 14 c
  assert_eq 0 "$RC" "rc"
  assert_eq "feature/14-c" "$(git branch --show-current)" "branch"
  assert_eq 1 "$(git branch --list 'merged/12-a-*' | wc -l | tr -d ' ')" "12 retired"
  assert_eq 1 "$(git branch --list 'merged/13-b-*' | wc -l | tr -d ' ')" "13 retired"
  assert_eq "" "$(git branch --list 'feature/12-a' 'feature/13-b')" "no old feature branches"
}
