#!/usr/bin/env bash
# テスト用の道具。各テストは先頭で setup_origin を呼ぶ。
TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

fail() { FAILED=1; printf '  失敗: %s\n' "$*" >&2; }

assert_eq() {
  [ "$1" = "$2" ] || fail "$3 (期待: [$1] 実際: [$2])"
}
assert_contains() {
  case "$1" in *"$2"*) ;; *) fail "$3 ([$2] が含まれていません) 内容: $1" ;; esac
}
assert_not_contains() {
  case "$1" in *"$2"*) fail "$3 ([$2] が含まれています) 内容: $1" ;; esac
}
assert_file() { [ -e "$1" ] || fail "ファイルがありません: $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "ファイルが残っています: $1"; }

# 一時フォルダに origin(bare)と seed(テンプレートを main にコミットして push 済み)を作る
setup_origin() {
  T=$(mktemp -d)
  trap 'rm -rf "$T"' EXIT
  export T
  export GIT_CONFIG_GLOBAL="$T/gitconfig"
  git config --global user.name Tester
  git config --global user.email tester@example.com
  git config --global init.defaultBranch main
  git init -q --bare -b main "$T/origin.git"
  git clone -q "$T/origin.git" "$T/seed" 2>/dev/null
  (
    cd "$T/seed" || exit 1
    git switch -q -C main
    for p in scripts .vscode PR.md .gitignore .gitattributes local; do
      cp -R "$TEMPLATE_ROOT/$p" .
    done
    git add -A && git commit -qm "seed" && git push -q -u origin main
  ) || fail "seed の作成に失敗"
  git -C "$T/origin.git" symbolic-ref HEAD refs/heads/main
  export OPEN_URL_FILE="$T/url.txt"
}

# clone_as <name> : origin を clone して入る。ブランチの持ち主の判定(作者の名前・メール)が
# 人ごとに分かれるよう、その clone だけに <name> と <name>@example.com を設定する
clone_as() {
  git clone -q "$T/origin.git" "$T/$1" 2>/dev/null
  cd "$T/$1" || return 1
  git config user.name "$1"
  git config user.email "$1@example.com"
}

# pick <branch> [続けて入力する行...] : 「ブランチ切り替え」の一覧で <branch> を選ぶ入力を $T/in に書く
pick() {
  local b="$1" i=0 r found=""; shift
  git fetch -q --prune origin
  while IFS= read -r r; do
    i=$((i+1))
    [ "$r" = "origin/$b" ] && { found=1; break; }
  done < <(git for-each-ref --sort=-committerdate --format='%(refname:short)' 'refs/remotes/origin/feature/*')
  [ -n "$found" ] || fail "pick: 一覧に $b がありません"
  printf '%s\n' "$i" "$@" > "$T/in"
}

# 今いる自分のブランチを「ブランチ切り替え」で選び直す(記録して送る)
save_here() {
  pick "$(git branch --show-current)"
  INPUT="$T/in" run switch
}

# run <menu> [args...] : OUT(標準出力+標準エラー)と RC を設定する
run() {
  local menu="$1"; shift
  OUT=$(bash "scripts/$menu.sh" "$@" < "${INPUT:-/dev/null}" 2>&1)
  RC=$?
}

merge_and_delete_remote() {
  (
    cd "$T/seed" || exit 1
    git fetch -q origin &&
    git merge -q --squash "origin/$1" >/dev/null 2>&1 &&
    git commit -qm "squash $1" &&
    git push -q origin main &&
    git push -q origin --delete "$1"
  ) || fail "merge_and_delete_remote $1 に失敗"
}
