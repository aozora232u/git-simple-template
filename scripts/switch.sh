#!/usr/bin/env bash
# ブランチ切り替え: GitHub にある作業ブランチの一覧から選んで切り替える。
# レビュー(他人の作業を手元で動かす)と、自分のブランチに戻るのに使う。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fetch_all
mapfile -t branches < <(git for-each-ref --sort=-committerdate \
  --format='%(refname:short)|%(authorname)|%(committerdate:relative)' 'refs/remotes/origin/feature/*')
[ "${#branches[@]}" -gt 0 ] || stop "切り替えられるブランチがまだありません。"

say "どのブランチに切り替えますか?"
for i in "${!branches[@]}"; do
  IFS='|' read -r b a d <<< "${branches[$i]}"
  printf '  %2d) %-28s %s(%s)\n' "$((i+1))" "${b#origin/}" "$a" "$d"
done
printf '   0) やめる\n番号を入力して Enter: '
read -r n
if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#branches[@]}" ]; then
  say "中止しました。"
  exit 0
fi
target="${branches[$((n-1))]%%|*}"
target="${target#origin/}"

if [ "$target" = "$(current_branch)" ]; then
  if is_feature; then save "作業中"; fi
  refresh_branch
  say "すでに $target にいます。最新の状態にしました。"
  exit 0
fi

if is_feature; then save "作業中"; fi
if ! git switch -q "$target"; then
  stop "切り替えられませんでした。変更したファイルが切り替え先の内容とぶつかっています。「やり直し(main に戻る)」を実行してから(変更は控えに残ります)、もう一度実行してください。分からなければリーダーに相談してください。"
fi
refresh_branch
say "$target に切り替えました。動かして確認してください。自分の作業に戻るには「作業開始」で自分の Issue 番号を入れてください。"
