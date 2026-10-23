#!/usr/bin/env bash
# 作業開始: main を最新にして、Issue ごとの作業ブランチを作る。既にあればそれに戻る。
# 使い方: start.sh <Issue番号> [短い英語の名前]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

issue="${1:-}"
name="${2:-}"
[[ "$issue" =~ ^[0-9]+$ ]] || stop "Issue の番号は数字で入力してください(例: 12)。"
# 名前は小文字英数字とハイフンだけにする
name=$(printf '%s' "$name" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')

# 1. 今の作業を記録(feature ブランチ上のときだけ。main 上の変更は新ブランチへ持ち越す)
fetch_all
if is_feature; then
  if upstream_deleted; then
    # 提出・マージ済みで GitHub から消えたブランチ。手元の控えとして退避し、変更は新しいブランチへ持ち越す
    old=$(current_branch)
    git branch -m "$old" "merged/${old#feature/}-$(date '+%Y%m%d-%H%M%S')" || die "ブランチの退避に失敗しました。"
    say "ブランチ $old は提出とマージが終わっているので、手元の控え(merged/...)に退避しました。"
  else
    save "作業中"
  fi
fi

# 2. 同じ番号のブランチが既にあれば、それに戻る
existing=$(git for-each-ref --format='%(refname:short)' \
  "refs/heads/feature/${issue}" "refs/heads/feature/${issue}-*" | head -1)
if [ -z "$existing" ]; then
  existing=$(git for-each-ref --format='%(refname:short)' \
    "refs/remotes/origin/feature/${issue}" "refs/remotes/origin/feature/${issue}-*" | head -1 | sed 's|^origin/||')
fi
if [ -n "$existing" ]; then
  if ! git switch -q "$existing"; then
    stop "ブランチ $existing に切り替えられませんでした。変更したファイルが切り替え先の内容とぶつかっています。「やり直し(main に戻る)」を実行してから(変更は控えに残ります)、もう一度実行してください。分からなければリーダーに相談してください。"
  fi
  refresh_branch
  say "ブランチ $existing に戻りました。続きを作業してください。終わったら PR.md を書いて「提出」を実行してください。"
  exit 0
fi

# 3. main を最新にして新しいブランチを作る
update_main
branch="feature/${issue}"
[ -n "$name" ] && branch="feature/${issue}-${name}"
git switch -q -c "$branch" || die "ブランチを作れませんでした。"
git push -q -u origin "$branch" || die "GitHub への送信に失敗しました。"
save "作業中"   # 持ち越した変更があれば、ここで新しいブランチに記録して送る
say "ブランチ $branch で作業できます。Issue #${issue} の作業をしてください。終わったら PR.md を書いて「提出」を実行してください。"
