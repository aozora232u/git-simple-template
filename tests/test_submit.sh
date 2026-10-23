#!/usr/bin/env bash
# submit.sh の今の動きを固定するテスト

write_pr() {
  sed -i '/^## やったこと/{n;s/.*/- ログイン画面/}' PR.md
}

test_submit_requires_pr_md() {
  setup_origin
  clone_as alice; run start 12 login
  run submit
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "PR.md に説明を書いてから" "msg"
}

test_submit_first_time() {
  setup_origin
  clone_as alice; run start 12 login
  write_pr
  run submit
  assert_eq 0 "$RC" "rc"
  local url; url=$(cat "$T/url.txt")
  assert_contains "$url" "/compare/main...feature/12-login?expand=1" "compare url"
  assert_contains "$url" "title=%2312%20login" "title"
  assert_contains "$url" "Closes%20%2312" "closes"
  git diff --quiet origin/main -- PR.md || fail "PR.md is not template"
  assert_eq 1 "$(ls local/pr-history/*_feature_12-login.md | wc -l | tr -d ' ')" "history"
  assert_file local/pr-history/feature_12-login.submitted
}

test_submit_resubmit() {
  setup_origin
  clone_as alice; run start 12 login
  write_pr; run submit
  echo c > c.txt
  run submit
  assert_contains "$OUT" "提出済みの PR に自動で反映されています" "msg"
  git -C "$T/origin.git" show feature/12-login:c.txt >/dev/null 2>&1 || fail "c.txt not on origin"
}

test_submit_from_main_stops() {
  setup_origin
  clone_as alice; run submit
  assert_contains "$OUT" "main からは提出できません" "msg"
}

test_submit_on_merged_branch_stops() {
  setup_origin
  clone_as alice; run start 12 login
  echo a > a.txt; write_pr; run submit
  merge_and_delete_remote feature/12-login
  echo d > d.txt
  run submit
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "GitHub から削除されています" "msg"
  assert_not_contains "$OUT" "反映されています" "no false success"
}
