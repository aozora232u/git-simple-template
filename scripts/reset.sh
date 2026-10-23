#!/usr/bin/env bash
# やり直し(main に戻る): 切り替えられなくなったときの最終手段。
# 記録していない変更を控え(git stash)に残してから作業場所を元に戻し、main の最新に戻る。
# 控えは「控えを戻す」で自分のブランチに当て直す。ファイルを丸ごと写し戻すと、
# その間に他の人が main で変えた内容を黙って消してしまうため、差分として控える。
# GitHub へは何も送らない。ブランチも消さない(記録済みの内容はブランチに残る)。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fetch_all
abort_merge

branch=$(current_branch)
[ -n "$branch" ] || branch="detached"

if [ -z "$(git status --porcelain --untracked-files=all)" ]; then
  update_main
  drop_view_branches
  say "変更したファイルはありませんでした。main の最新に戻りました。"
  exit 0
fi

say "今のブランチ: $branch"
say "次のファイルの変更を控えに残してから元に戻し、main の最新に戻ります。"
git -c core.quotepath=false status --short --untracked-files=all
printf '\nよろしいですか? (y/N): '
read -r ans
case "$ans" in y|Y) ;; *) say "中止しました。何も変えていません。"; exit 0 ;; esac

# 1. 控えに残す(新しく作ったファイルも含む)。作業場所は元に戻る
git stash push -q -u -m "${STASH_LABEL} ${branch} $(date '+%Y-%m-%d %H:%M')" || die "控えに残せませんでした。何も変えていません。"

# 2. main の最新に戻る(閲覧用ブランチは片付ける)
update_main
drop_view_branches

say "main の最新に戻りました。変更は控えに残してあります。
必要なら「ブランチ切り替え」で自分のブランチに戻ってから、「控えを戻す」を実行してください。"
