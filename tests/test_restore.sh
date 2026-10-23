#!/usr/bin/env bash
# restore.sh の今の動きを固定するテスト

test_restore_conflict_keeps_stash() {
  setup_origin
  clone_as alice; run start 12 login
  echo base > same.txt; save_here
  echo stashed > same.txt
  printf 'y\n' > "$T/in"; INPUT="$T/in" run reset
  pick feature/12-login; INPUT="$T/in" run switch
  echo mine > same.txt; save_here       # 控えと同じ行を変えて記録する
  printf '1\n' > "$T/in"; INPUT="$T/in" run restore
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "衝突しました" "msg"
  assert_eq "" "$(git status --porcelain --untracked-files=all)" "clean"
  assert_eq "mine" "$(cat same.txt)" "own content kept"
  assert_eq 1 "$(git stash list | wc -l | tr -d ' ')" "stash kept"
}

test_restore_requires_own_branch() {
  setup_origin
  clone_as alice; run restore
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "自分のブランチに戻します" "msg"
}
