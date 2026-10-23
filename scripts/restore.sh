#!/usr/bin/env bash
# 控えを戻す: 「やり直し」で残した控えの一覧から選んで、今の自分のブランチに当て直す。
# 差分として当て直すので、その間に他の人が変えた内容は残る。同じ箇所を変えていたら取り消して止まる。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

on_own_feature || stop "控えは自分のブランチに戻します。先に「ブランチ切り替え」で自分のブランチを選んでください(新しく始めるなら「作業開始」)。"
if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  stop "記録していない変更があります。先に「ブランチ切り替え」で今のブランチ($(current_branch))を選ぶと記録されます。その後、もう一度実行してください。"
fi

# やり直しで作った控えだけを並べる(%gd は stash@{n}、%gs は「On ブランチ: ラベル ...」)
mapfile -t stashes < <(git stash list --format='%gd|%gs' | grep -F ": ${STASH_LABEL} ")
[ "${#stashes[@]}" -gt 0 ] || stop "戻せる控えはありません。"

say "どの控えを戻しますか?(元のブランチ・日時)"
for i in "${!stashes[@]}"; do
  label="${stashes[$i]#*: ${STASH_LABEL} }"
  printf '  %2d) %s\n' "$((i+1))" "$label"
done
printf '   0) やめる\n番号を入力して Enter: '
read -r n
if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#stashes[@]}" ]; then
  say "中止しました。"
  exit 0
fi
ref="${stashes[$((n-1))]%%|*}"

if ! git stash apply -q "$ref"; then
  # 当て直す前は変更がなかったので、元に戻せば手元は元のまま。控えも残る
  { git reset -q --hard && git clean -q -fd; } || die "元に戻せませんでした。"
  die "控えの変更が、今のブランチの内容と衝突しました。戻すのは取り消したので、手元は元のままです(控えも残っています)。"
fi
git stash drop -q "$ref"
say "控えを戻しました。内容を確かめて、続きを作業してください。"
