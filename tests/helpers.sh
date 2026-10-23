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
  export OPEN_URL_FILE="$T/url.txt" OPEN_DIR_FILE="$T/dir.txt"
}

clone_as() {
  git clone -q "$T/origin.git" "$T/$1" 2>/dev/null
  cd "$T/$1" || return 1
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
    git merge -q --squash "origin/$1" >/dev/null &&
    git commit -qm "squash $1" &&
    git push -q origin main &&
    git push -q origin --delete "$1"
  ) || fail "merge_and_delete_remote $1 に失敗"
}
