#!/usr/bin/env bash
# reset.sh の今の動きを固定するテスト

test_reset_stashes_and_restore_applies() {
  setup_origin
  clone_as alice; run start 12 login
  echo edited > PR.md; echo n > new.txt
  printf 'y\n' > "$T/in"; INPUT="$T/in" run reset
  assert_eq 0 "$RC" "rc"
  assert_contains "$OUT" "new.txt" "changed file listed"
  assert_contains "$OUT" "PR.md" "changed file listed"
  assert_eq "main" "$(git branch --show-current)" "branch"
  assert_eq "" "$(git status --porcelain --untracked-files=all)" "clean"
  assert_contains "$(git stash list)" "やり直し" "stashed"
  pick feature/12-login; INPUT="$T/in" run switch
  assert_eq "feature/12-login" "$(git branch --show-current)" "back on own branch"
  printf '1\n' > "$T/in"; INPUT="$T/in" run restore
  assert_eq 0 "$RC" "rc restore"
  assert_contains "$OUT" "控えを戻しました" "msg"
  assert_eq "edited" "$(cat PR.md)" "PR.md restored"
  assert_eq "n" "$(cat new.txt)" "new.txt restored"
  assert_eq "" "$(git stash list)" "stash dropped"
}

test_reset_cancel() {
  setup_origin
  clone_as alice; run start 12 login
  echo n > new.txt
  printf 'n\n' > "$T/in"; INPUT="$T/in" run reset
  assert_contains "$OUT" "中止しました" "msg"
  assert_file new.txt
  assert_eq "" "$(git stash list)" "no stash"
}

test_reset_japanese_filename() {
  setup_origin
  clone_as alice; run start 12 login
  echo m > "メモ 1.txt"
  printf 'y\n' > "$T/in"; INPUT="$T/in" run reset
  assert_contains "$OUT" "メモ 1.txt" "listed"
  assert_no_file "メモ 1.txt"
  assert_contains "$(git -c core.quotepath=false show --format= --name-only 'stash@{0}^3')" "メモ 1.txt" "in stash"
}
