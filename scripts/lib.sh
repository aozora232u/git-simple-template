#!/usr/bin/env bash
# 共通処理。各スクリプトの先頭で source する。
# 読者: リーダー。メンバーはこのファイルを触らない。
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# ---- 表示 ----
say()  { printf '\n%s\n' "$*"; }
# メンバー自身で直せる失敗
stop() { printf '\n%s\n' "$*"; exit 1; }
# 環境側の失敗(リーダーに相談)
die()  { printf '\n%s\n\nリーダーに相談してください。\n' "$*"; exit 1; }

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
    stop "ファイルを別の場所に移すか、.gitignore に追加してから、もう一度実行してください。分からなければリーダーに相談してください。"
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
    stop "このブランチ($(current_branch))は提出とマージが終わり、GitHub から削除されています。「やり直し(main に戻る)」を実行すると、今の変更を控えに残して main に戻れます。その後「作業開始」で新しい Issue 番号を入れ、控えから必要な内容を写してください。分からなければリーダーに相談してください。"
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
    git switch -q main || stop "main に切り替えられませんでした。変更したファイルが main の内容とぶつかっています。「やり直し(main に戻る)」を実行してください(変更は控えに残ります)。分からなければリーダーに相談してください。"
  fi
  git pull -q --ff-only origin main || stop "main を最新にできませんでした。「やり直し(main に戻る)」を実行してください(変更は控えに残ります)。分からなければリーダーに相談してください。"
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
