#!/usr/bin/env bash
# 共通処理。各スクリプトの先頭で source する。
# 読者: リーダー。メンバーはこのファイルを触らない。
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# ---- ログ(local/logs に 1 回の実行につき 1 ファイル) ----
# 画面にはやさしい文章だけを出し、Git の出力や状態はログに残す。
# ログを書けないときは LOG_FILE を空にして、本来の操作はそのまま続ける。
LOG_KEEP=50
LOG_FILE=""
LOG_TMP=""
LOG_DONE=""   # 結果(stop / die)を書いたら 1

# ログに 1 行書く(書けなくても何もしない)
log() { [ -n "$LOG_FILE" ] && printf '%s\n' "$*" 2>/dev/null >> "$LOG_FILE"; return 0; }

# ブランチ、HEAD、変更中のファイルを書く
log_state() {
  [ -n "$LOG_FILE" ] || return 0
  {
    printf '\n---- %s ----\n' "$1"
    printf 'ブランチ: %s\n' "$(command git branch --show-current 2>&1)"
    printf 'HEAD: %s\n' "$(command git log -1 --format='%h %s' 2>&1)"
    printf 'git status --porcelain:\n'
    command git -c core.quotepath=false status --porcelain 2>&1
  } 2>/dev/null >> "$LOG_FILE"
}

# Git を実行し、コマンド・出力・終了コードをログに書く。出力と終了コードは呼び出し元にそのまま返す
git() {
  [ -n "$LOG_FILE" ] || { command git "$@"; return; }
  local out="$LOG_TMP/$BASHPID.out" err="$LOG_TMP/$BASHPID.err" rc
  command git "$@" > "$out" 2> "$err"
  rc=$?
  {
    printf '\n$ git %s\n' "$*"
    if [ -s "$out" ]; then printf '[stdout]\n'; tr '\0' '\n' < "$out"; printf '\n'; fi
    if [ -s "$err" ]; then printf '[stderr]\n'; cat "$err"; fi
    printf '[終了コード] %s\n' "$rc"
  } 2>/dev/null >> "$LOG_FILE"
  if [ -s "$out" ]; then cat "$out"; fi
  if [ -s "$err" ]; then cat "$err" >&2; fi
  return "$rc"
}

# 終了時: stop / die を書いていなければ、終了コードで成功かどうかを書く
log_finish() {
  local rc="$1"
  if [ -z "$LOG_DONE" ]; then
    if [ "$rc" -eq 0 ]; then log "結果: 成功"; else log "結果: 終了コード $rc"; fi
  fi
  [ -n "$LOG_TMP" ] && rm -rf "$LOG_TMP"
}

log_start() {
  local t stamp now name n=2 LC_ALL=C old menu="${0##*/}"
  menu="${menu%.sh}"
  printf -v t '%(%s)T' -1
  printf -v stamp '%(%Y-%m-%d_%H%M%S)T' "$t"
  printf -v now '%(%Y-%m-%d %H:%M:%S)T' "$t"
  name="${stamp}_${menu}"
  mkdir -p local/logs 2>/dev/null || return 0
  LOG_FILE="local/logs/${name}.log"
  # 同じ秒に同じ名前があれば _2、_3 … を付ける
  while [ -e "$LOG_FILE" ]; do LOG_FILE="local/logs/${name}_${n}.log"; n=$((n+1)); done
  if ! : 2>/dev/null > "$LOG_FILE"; then LOG_FILE=""; return 0; fi
  LOG_TMP=$(mktemp -d 2>/dev/null) || { LOG_FILE=""; return 0; }
  trap 'log_finish $?' EXIT
  # 古いログを消す(名前順 = 日時順。全メニュー合計で新しい LOG_KEEP 件を残す)
  old=(local/logs/*.log)
  if [ "${#old[@]}" -gt "$LOG_KEEP" ]; then
    rm -f "${old[@]:0:${#old[@]}-LOG_KEEP}"
  fi
  log "メニュー: $menu"
  log "引数: $*"
  log "日時: $now"
  log "$(command git --version 2>&1)"
  log_state "開始時"
}
log_start "$@"

# ---- 表示 ----
say()  { log "画面: $*"; printf '\n%s\n' "$*"; }
# メンバー自身で直せる失敗
stop() {
  LOG_DONE=1; log "結果: stop"; log "$*"; log_state "終了時"
  printf '\n%s\n' "$*"; exit 1
}
# 環境側の失敗(チームのリーダーに相談。ログがあればその場所も出す)
die() {
  LOG_DONE=1; log "結果: die"; log "$*"; log_state "終了時"
  if [ -n "$LOG_FILE" ]; then
    printf '\n%s\n\nチームのリーダーに相談してください。そのとき、このログファイルを見せてください: %s\n' "$*" "$LOG_FILE"
  else
    printf '\n%s\n\nチームのリーダーに相談してください。\n' "$*"
  fi
  exit 1
}

# ---- 名前とメールの設定(最初に 1 回) ----
if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
  stop "最初に 1 回だけ、名前とメールの設定が必要です。VS Code のターミナルで次の 2 行を打ってから、もう一度実行してください。
  git config --global user.name \"あなたの名前\"
  git config --global user.email \"GitHub の Settings → Emails にある ...@users.noreply.github.com のアドレス\""
fi

# ---- 状態 ----
current_branch() { git branch --show-current; }
on_main()    { [ "$(current_branch)" = "main" ]; }
is_feature() { case "$(current_branch)" in feature/*) return 0 ;; *) return 1 ;; esac; }
has_upstream() { git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; }
# 追跡先のブランチが GitHub から消えている(提出・マージ済みで自動削除された)
upstream_deleted() {
  local b; b=$(current_branch)
  [ -n "$(git config "branch.${b}.merge")" ] && ! git show-ref -q --verify "refs/remotes/origin/${b}"
}
# マージの途中なら取り消す(途中でなければ何もしない)
abort_merge() { [ -f "$(git rev-parse --git-path MERGE_HEAD)" ] && git merge --abort; return 0; }

# ---- 秘密情報らしきファイルの検出 ----
check_secrets() {
  local bad
  bad=$(git status --porcelain --untracked-files=all | cut -c4- | sed 's/^"//; s/"$//' \
        | grep -E '(^|/)\.env($|\.)|\.(pem|key)$' || true)
  if [ -n "$bad" ]; then
    printf '\n次のファイルは秘密情報の可能性があるため記録しません:\n%s\n' "$bad"
    stop "ファイルを別の場所に移すか、.gitignore に追加してから、もう一度実行してください。分からなければチームのリーダーに相談してください。"
  fi
}

# ---- 記録して送る ----
# push が拒否されたら(同じブランチを他の人が更新した)、相手の変更を取り込んでからもう一度送る。
push_current() {
  local b; b=$(current_branch)
  if ! has_upstream; then
    git push -q -u origin "$b" || die "GitHub への送信に失敗しました。手元の記録は残っています。"
    return 0
  fi
  if git push -q origin "$b" 2>/dev/null; then return 0; fi
  git fetch -q origin || die "GitHub に接続できませんでした。ネットワークを確認してください。"
  if ! git merge -q --no-edit "origin/$b"; then
    abort_merge
    die "同じブランチを他の人が変更していて、あなたの変更と衝突しました。取り込みは取り消したので、手元は元のままです。"
  fi
  git push -q origin "$b" || die "GitHub への送信に失敗しました。手元の記録は残っています。"
}

# save <ラベル> : 手元の変更をすべて今のブランチに記録して送る(PR.md のメモも含む。提出時にテンプレートへ戻す)。
# 変更がなくても、送っていない記録があれば送る。
save() {
  local label="${1:-作業中}"
  local changes; changes=$(git status --porcelain)
  if upstream_deleted; then
    [ -z "$changes" ] && return 0
    stop "このブランチ($(current_branch))は提出とマージが終わり、GitHub から削除されています。「やり直し(main に戻る)」を実行すると、今の変更を控えに残して main に戻れます。その後「作業開始」で新しい Issue 番号を入れ、控えから必要な内容を写してください。分からなければチームのリーダーに相談してください。"
  fi
  if [ -n "$changes" ]; then
    check_secrets
    git add -A
    git commit -q -m "$label $(date '+%Y-%m-%d %H:%M')" || die "記録に失敗しました。"
  fi
  push_current
}

# ---- 最新化 ----
fetch_all() {
  git fetch -q --prune origin || die "GitHub に接続できませんでした。ネットワークを確認してください。"
}

# main に切り替えて最新にする。
# 古い main を経由すると、変更中のファイルとぶつかって切り替えられないことがあるため、
# main 以外にいるときは、先に手元の main を最新に進めてから切り替える。
update_main() {
  if ! on_main; then
    git fetch -q origin main:main || die "手元の main を最新にできませんでした。"
    git switch -q main || stop "main に切り替えられませんでした。変更したファイルが main の内容とぶつかっています。「やり直し(main に戻る)」を実行してください(変更は控えに残ります)。分からなければチームのリーダーに相談してください。"
  fi
  git pull -q --ff-only origin main || stop "main を最新にできませんでした。「やり直し(main に戻る)」を実行してください(変更は控えに残ります)。分からなければチームのリーダーに相談してください。"
}

# 今のブランチを最新にし、main の変更を取り込む。衝突したら取り消して止まる。
refresh_branch() {
  if has_upstream; then
    git pull -q --ff-only || die "ブランチを最新にできませんでした。"
  fi
  if ! git merge -q --no-edit origin/main; then
    abort_merge
    die "main の変更とあなたの変更が衝突しました。取り込みは取り消したので、手元は元のままです。"
  fi
  push_current
}

# ---- URL ----
# UTF-8 のバイト列を %XX にする。英数字と . ~ _ - はそのまま。
urlencode() {
  local LC_ALL=C s="$1" i c out=""
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

open_url() {
  # 試験用: OPEN_URL_FILE が設定されていればブラウザを開かず URL をそのファイルに書く
  if [ -n "${OPEN_URL_FILE:-}" ]; then printf '%s\n' "$1" > "$OPEN_URL_FILE"; return 0; fi
  # cmd の start は URL の & で切れるので使わない
  rundll32.exe url.dll,FileProtocolHandler "$1" \
    || { say "ブラウザを開けませんでした。次の URL をブラウザに貼ってください:"; printf '%s\n' "$1"; }
}
