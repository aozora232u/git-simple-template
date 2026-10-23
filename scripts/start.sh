#!/usr/bin/env bash
# 作業開始: main を最新にして、Issue ごとの作業ブランチを新しく作る。既にあれば止まる。
# 使い方: start.sh <Issue番号> [短い英語の名前]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

issue="${1:-}"
name="${2:-}"
[[ "$issue" =~ ^[0-9]+$ ]] || stop "Issue の番号は数字で入力してください(例: 12)。"
# 名前は小文字英数字とハイフンだけにする
name=$(printf '%s' "$name" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')

# 1. 今の作業を記録(自分の feature ブランチ上のときだけ。main 上の変更は新ブランチへ持ち越す)
fetch_all
if on_own_feature && ! upstream_deleted; then
  save "作業中"
fi
# 他の人のブランチでの変更は持ち越さない(確認してから捨てる)
leave_view
# マージ済みで GitHub から消えたブランチは退避する。今いるブランチが該当すれば、変更は新しいブランチへ持ち越す
retire_merged_branches

# 2. 同じ名前のブランチが既にあれば止まる(既存のブランチへ移るのは「ブランチ切り替え」だけ)
branch="feature/${issue}"
[ -n "$name" ] && branch="feature/${issue}-${name}"
if git show-ref -q --verify "refs/heads/${branch}" || git show-ref -q --verify "refs/remotes/origin/${branch}"; then
  stop "ブランチ $branch は既にあります。続きを作業するなら「ブランチ切り替え」で選んでください。新しく始めるなら、別の名前を入れてもう一度実行してください。"
fi

# 3. main を最新にして新しいブランチを作る
update_main
git switch -q -c "$branch" || die "ブランチを作れませんでした。"
git push -q -u origin "$branch" || die "GitHub への送信に失敗しました。"
save "作業中"   # 持ち越した変更があれば、ここで新しいブランチに記録して送る
drop_view_branches
say "ブランチ $branch で作業できます。Issue #${issue} の作業をしてください。終わったら PR.md を書いて「提出」を実行してください。"
