#!/usr/bin/env bash
# やり直し(main に戻る): 切り替えられなくなったときの最終手段。
# 記録していない変更を local/backup/ に控えてから作業場所を元に戻し、main の最新に戻る。
# GitHub へは何も送らない。ブランチも消さない(記録済みの内容はブランチに残る)。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

fetch_all
abort_merge

branch=$(current_branch)
[ -n "$branch" ] || branch="detached"

# 変更・新規・削除されたファイル(名前に日本語や空白があっても崩れないよう -z で読む)
mapfile -d '' -t entries < <(git status --porcelain=v1 -z --untracked-files=all)
paths=()
for (( i=0; i<${#entries[@]}; i++ )); do
  e="${entries[$i]}"
  paths+=("${e:3}")
  # 名前の変更は「新しい名前」の後に「元の名前」が続く
  case "${e:0:1}" in R|C) i=$((i+1)); paths+=("${entries[$i]}") ;; esac
done

if [ "${#paths[@]}" -eq 0 ]; then
  update_main
  say "変更したファイルはありませんでした。main の最新に戻りました。"
  exit 0
fi

say "今のブランチ: $branch"
say "次のファイルを控えに残してから元に戻し、main の最新に戻ります。"
printf '  %s\n' "${paths[@]}"
printf '\nよろしいですか? (y/N): '
read -r ans
case "$ans" in y|Y) ;; *) say "中止しました。何も変えていません。"; exit 0 ;; esac

# 1. 控えを取る
backup="local/backup/$(date '+%Y-%m-%d_%H%M%S')_${branch//\//_}"
mkdir -p "$backup" || die "控えのフォルダを作れませんでした。"
deleted=()
for p in "${paths[@]}"; do
  if [ -f "$p" ]; then
    mkdir -p "$backup/$(dirname "$p")" && cp -p "$p" "$backup/$p" || die "控えを取れませんでした($p)。何も変えていません。"
  else
    deleted+=("$p")
  fi
done
if [ "${#deleted[@]}" -gt 0 ]; then
  printf '%s\n' "${deleted[@]}" > "$backup/削除したファイル.txt"
fi

# 2. 作業場所を元に戻す(local/ は .gitignore の対象なので消えない)
git reset -q --hard || die "元に戻せませんでした。控えは $backup にあります。"
git clean -q -fd || die "元に戻せませんでした。控えは $backup にあります。"

# 3. main の最新に戻る
update_main

# 4. 控えのフォルダを開く
# 試験用: OPEN_DIR_FILE が設定されていればエクスプローラーを開かずパスをそのファイルに書く
if [ -n "${OPEN_DIR_FILE:-}" ]; then
  printf '%s\n' "$backup" > "$OPEN_DIR_FILE"
else
  explorer.exe "$(cygpath -w "$backup")" || true   # explorer.exe は成功しても 1 を返すことがある
fi
say "main の最新に戻りました。変更の控えは $backup にあります。
必要な内容は「作業開始」で自分のブランチに戻ってから写してください。控えは不要になったら消して構いません。"
