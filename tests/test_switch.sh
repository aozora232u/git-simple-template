#!/usr/bin/env bash
# switch.sh の今の動きを固定するテスト

# bob の作業ブランチ feature/20-bob を作り、1 回記録しておく
bob_branch() {
  clone_as bob; run start 20 bob
  echo b > b.txt; save_here
}

test_switch_own_branch_returns_and_merges_main() {
  setup_origin
  bob_branch
  clone_as alice; run start 12 login; git switch -q main
  (cd "$T/seed" && echo x > new.txt && git add . && git commit -qm m && git push -q)
  pick feature/12-login; INPUT="$T/in" run switch
  assert_eq 0 "$RC" "rc"
  assert_contains "$(printf '%s\n' "$OUT" | grep 'feature/12-login')" "← あなたのブランチ" "own mark"
  assert_not_contains "$(printf '%s\n' "$OUT" | grep 'feature/20-bob')" "← あなたのブランチ" "no mark on bob"
  assert_eq "feature/12-login" "$(git branch --show-current)" "branch"
  assert_file new.txt
}

test_switch_other_opens_view() {
  setup_origin
  bob_branch
  local before; before=$(git -C "$T/origin.git" rev-parse feature/20-bob)
  clone_as alice; run start 12 login
  pick feature/20-bob; INPUT="$T/in" run switch
  assert_eq 0 "$RC" "rc"
  assert_eq "view/feature/20-bob" "$(git branch --show-current)" "branch"
  assert_file b.txt
  assert_contains "$OUT" "閲覧用に開きました" "msg"
  assert_eq "$before" "$(git -C "$T/origin.git" rev-parse feature/20-bob)" "origin unchanged"
  assert_eq "" "$(git -C "$T/origin.git" for-each-ref 'refs/heads/view/')" "no view branch on origin"
}

test_switch_leave_view_discards_with_confirm() {
  setup_origin
  bob_branch
  clone_as alice; run start 12 login
  pick feature/20-bob; INPUT="$T/in" run switch
  echo changed > b.txt
  # n: 中止して変更を残す
  pick feature/12-login n; INPUT="$T/in" run switch
  assert_eq 1 "$RC" "rc on n"
  assert_eq "view/feature/20-bob" "$(git branch --show-current)" "still viewing"
  assert_eq "changed" "$(cat b.txt)" "change kept"
  # y: 変更を捨てて自分のブランチへ
  pick feature/12-login y; INPUT="$T/in" run switch
  assert_eq 0 "$RC" "rc on y"
  assert_contains "$OUT" "b.txt" "changed file listed"
  assert_eq "feature/12-login" "$(git branch --show-current)" "branch"
  assert_eq "" "$(git status --porcelain)" "clean"
  assert_eq "" "$(git branch --list 'view/*')" "view branch dropped"
  git -C "$T/origin.git" show feature/20-bob:b.txt | grep -qx b || fail "bob's branch changed on origin"
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
