#!/usr/bin/env bash
# 提出: PR.md の内容を控えてテンプレートに戻し、記録して送った上で、PR 作成ページをブラウザで開く。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

on_main && stop "main からは提出できません。先に「作業開始」で自分のブランチを作ってください。"
is_viewing && stop "他の人のブランチは提出できません。自分のブランチに戻るには「ブランチ切り替え」で選んでください。"
branch=$(current_branch)
issue=$(printf '%s' "$branch" | sed -E 's|^feature/([0-9]+).*|\1|')
[[ "$issue" =~ ^[0-9]+$ ]] || die "このブランチ($branch)は「作業開始」で作ったものではないため提出できません。"
name="${branch#feature/$issue}"; name="${name#-}"

mkdir -p local/pr-history
safe="${branch//\//_}"
marker="local/pr-history/${safe}.submitted"

fetch_all
if ! is_mine "$branch"; then
  stop "他の人のブランチは提出できません。自分のブランチに戻るには「ブランチ切り替え」で選んでください。"
fi
if upstream_deleted; then
  stop "このブランチ($branch)は提出とマージが終わり、GitHub から削除されています。続きの作業は「作業開始」で新しいブランチを作ってから行ってください。"
fi

# 記録して、main の変更を取り込んでから送る。衝突は GitHub ではなく手元で見つけて止まる
conflict_msg="main の変更とあなたの変更が衝突したため、提出を中止しました。取り込みは取り消したので、手元は元のままです。"

# PR.md がテンプレートのまま(= main 上のテンプレートと同じ)か
if git diff --quiet origin/main -- PR.md; then
  if [ -f "$marker" ]; then
    save "提出"
    merge_main || die "$conflict_msg"
    push_current
    say "記録して GitHub に送りました。提出済みの PR に自動で反映されています。"
    exit 0
  fi
  stop "PR.md に説明を書いてから「提出」を実行してください。"
fi

# 1. 控えを取り、PR.md を main 上のテンプレートに戻す
backup="local/pr-history/$(date '+%Y-%m-%d_%H%M%S')_${safe}.md"
cp PR.md "$backup"
git checkout -q origin/main -- PR.md

# 2. 記録して、main の変更を取り込んで送る(衝突したら PR.md を書いた内容に戻して止まる)
save "提出"
if ! merge_main; then
  cp "$backup" PR.md
  die "$conflict_msg PR.md も書いた内容に戻しました。"
fi
push_current
touch "$marker"

# 3. PR 作成ページを開く
repo=$(git remote get-url origin | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')
title="#${issue}"
[ -n "$name" ] && title="#${issue} ${name}"
body="$(cat "$backup")"$'\n\n'"Closes #${issue}"
url="https://github.com/${repo}/compare/main...${branch}?expand=1&title=$(urlencode "$title")&body=$(urlencode "$body")"
open_url "$url"
say "ブラウザで提出ページを開きました。内容を確認して「Create pull request」を押してください。提出メモの控えは ${backup} にあります。"
