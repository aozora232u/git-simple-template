#!/usr/bin/env bash
# ブランチ切り替え: GitHub にある作業ブランチの一覧から選んで切り替える。
# 自分のブランチに戻る(続きの作業)のと、レビュー(他人の作業を手元で動かす)に使う。
# 他人のブランチは閲覧用(view/...)に開き、記録も送信もしない。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fetch_all
mapfile -t branches < <(git for-each-ref --sort=-committerdate \
  --format='%(refname:short)|%(authorname)|%(committerdate:relative)' 'refs/remotes/origin/feature/*')
[ "${#branches[@]}" -gt 0 ] || stop "切り替えられるブランチがまだありません。"

say "どのブランチに切り替えますか?"
for i in "${!branches[@]}"; do
  IFS='|' read -r b a d <<< "${branches[$i]}"
  mark=""; is_mine "${b#origin/}" && mark=" ← あなたのブランチ"
  printf '  %2d) %-28s %s(%s)%s\n' "$((i+1))" "${b#origin/}" "$a" "$d" "$mark"
done
printf '   0) やめる\n番号を入力して Enter: '
read -r n
if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#branches[@]}" ]; then
  say "中止しました。"
  exit 0
fi
target="${branches[$((n-1))]%%|*}"
target="${target#origin/}"

# 今の作業を記録する(自分のブランチのときだけ)。他の人のブランチでの変更は確認してから捨てる
if on_own_feature; then save "作業中"; fi
leave_view

# 自分のブランチ: 切り替えて main を取り込み、送る
if is_mine "$target"; then
  if [ "$target" != "$(current_branch)" ] && ! git switch -q "$target"; then
    stop "切り替えられませんでした。変更したファイルが切り替え先の内容とぶつかっています。「やり直し(main に戻る)」を実行してから(変更は控えに残ります)、もう一度実行してください。分からなければチームのリーダーに相談してください。"
  fi
  refresh_branch
  drop_view_branches
  say "あなたのブランチ $target に切り替えて、main の最新を取り込みました。続きを作業してください。終わったら PR.md を書いて「提出」を実行してください。"
  exit 0
fi

# 他の人のブランチ: 閲覧用に開いて main を取り込む(手元だけ。GitHub には送らない)
if [ -n "$(git status --porcelain)" ]; then
  stop "記録していない変更があるため、他の人のブランチを開けません。「やり直し(main に戻る)」を実行すると、変更を控えに残してから main に戻れます。その後、もう一度実行してください。"
fi
git switch -q --no-track -C "view/$target" "origin/$target" || die "ブランチ $target を開けませんでした。"
drop_view_branches
if merge_main; then
  note="main の最新も取り込んであります。"
else
  note="main と衝突するため、main は取り込まずにそのままの状態で開いています。"
fi
say "$target(他の人のブランチ)を閲覧用に開きました。$note
動かして確認してください。ここで変更しても記録されず、GitHub にも送られません。自分の作業に戻るには、もう一度「ブランチ切り替え」で自分のブランチを選んでください。"
