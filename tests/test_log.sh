#!/usr/bin/env bash
# 実行ログ(local/logs)のテスト

# 最新のログ(名前順で最後。同じ秒の _2 も拾う)
latest_log() { ls local/logs/*_"$1"*.log 2>/dev/null | LC_ALL=C sort | tail -1; }

test_log_created_per_menu() {
  setup_origin
  clone_as alice; run start 12 login
  local f; f=$(latest_log start); assert_file "$f"
  local c; c=$(cat "$f")
  assert_contains "$c" "メニュー: start" "menu"
  assert_contains "$c" "引数: 12 login" "args"
  assert_contains "$c" "開始時" "state at start"
  assert_contains "$c" "git version" "git --version"
  assert_contains "$c" "push" "git cmd logged"
  assert_contains "$c" "結果: 成功" "result"
}

test_log_records_git_stderr_on_die() {
  setup_origin
  clone_as alice; run start 12 login
  git remote set-url origin "$T/nowhere.git"   # 接続できない状態を作る
  run start 12
  assert_eq 1 "$RC" "rc"
  local f; f=$(latest_log start)
  assert_contains "$OUT" "チームのリーダーに相談してください。そのとき、このログファイルを見せてください: $f" "path shown"
  assert_contains "$(cat "$f")" "nowhere.git" "git stderr logged"
  assert_contains "$(cat "$f")" "結果: die" "result"
  assert_contains "$(cat "$f")" "終了時" "state at end"
}

test_log_stop_hides_path() {
  setup_origin
  clone_as alice; run start abc
  assert_not_contains "$OUT" "local/logs" "no path"
  assert_contains "$(cat "$(latest_log start)")" "結果: stop" "logged"
}

test_log_keeps_latest_50() {
  setup_origin
  clone_as alice; mkdir -p local/logs
  local i
  for i in $(seq -w 1 60); do : > "local/logs/2000-01-01_0000${i}_start.log"; done
  run switch
  assert_eq 50 "$(ls local/logs | wc -l | tr -d ' ')" "count"
  assert_no_file local/logs/2000-01-01_000001_start.log
  assert_file local/logs/2000-01-01_000060_start.log
}

test_log_same_second_distinct() {
  setup_origin
  clone_as alice; mkdir -p local/logs
  # これから数秒分の名前を先に作っておき、同じ秒の衝突を必ず起こす
  local s
  for s in 0 1 2 3 4 5; do : > "local/logs/$(date -d "+$s sec" '+%Y-%m-%d_%H%M%S')_start.log"; done
  run start abc
  local f; f=$(ls local/logs/*_start_2.log 2>/dev/null)
  assert_file "$f"
  assert_contains "$(cat "$f")" "結果: stop" "new log written to _2"
}

test_log_unwritable_continues() {
  setup_origin
  clone_as alice; rm -rf local/logs; : > local/logs   # フォルダを作れない状態
  run start 12 login
  assert_eq 0 "$RC" "rc"
  assert_eq "feature/12-login" "$(git branch --show-current)" "branch"
  assert_eq "" "$(git status --porcelain)" "clean"
}

test_log_unwritable_die_hides_path() {
  setup_origin
  clone_as alice; run start 12 login
  rm -rf local/logs; : > local/logs
  git remote set-url origin "$T/nowhere.git"
  run start 12
  assert_eq 1 "$RC" "rc"
  assert_contains "$OUT" "チームのリーダーに相談してください。" "msg"
  assert_not_contains "$OUT" "ログファイル" "no path"
}

test_log_before_name_check() {
  setup_origin
  clone_as alice
  git config --unset user.name; git config --unset user.email
  GIT_CONFIG_GLOBAL=/dev/null run start 12   # 名前とメールが未設定の状態
  assert_contains "$OUT" "名前とメールの設定が必要です" "msg"
  assert_contains "$(cat "$(latest_log start)")" "結果: stop" "logged"
}

test_log_keeps_interactive_input() {
  setup_origin
  clone_as alice; run start 12 login
  clone_as bob
  pick feature/12-login; INPUT="$T/in" run switch
  assert_eq "view/feature/12-login" "$(git branch --show-current)" "switched"
  assert_contains "$(cat "$(latest_log switch)")" "結果: 成功" "logged"
}

test_log_restore_name() {
  setup_origin
  clone_as alice; run restore
  local f; f=$(latest_log restore); assert_file "$f"
  assert_contains "$(cat "$f")" "メニュー: restore" "menu"
}

test_messages_say_team_leader() {
  ! grep -n "リーダー" "$TEMPLATE_ROOT"/scripts/*.sh | grep -v "チームのリーダー" | grep -v "読者: リーダー" \
    || fail "plain リーダー left"
}
