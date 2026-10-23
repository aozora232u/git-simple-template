#!/usr/bin/env bash
# テンプレートそのものの確認(配るときに NaganoTeamD の名残やガイドの抜けがないか)

test_no_naganoteamd_strings() {
  local f hits=""
  while IFS= read -r f; do
    [ "$f" = "tests/test_template.sh" ] && continue   # このファイルは禁止文字列を書くので除く
    [ -f "$TEMPLATE_ROOT/$f" ] || continue
    if grep -q -e 'NaganoTeamD' -e 'Team D' -e 'env\.js' -e 'erraform' "$TEMPLATE_ROOT/$f"; then
      hits="$hits $f"
    fi
  done < <(git -C "$TEMPLATE_ROOT" ls-files --cached --others --exclude-standard)
  [ -z "$hits" ] || fail "NaganoTeamD 固有の文字列が残っています:$hits"
}

test_leader_guide_covers_all_messages() {
  local guide="$TEMPLATE_ROOT/docs/git/leader-guide.md" key n=0
  [ -f "$guide" ] || { fail "docs/git/leader-guide.md がありません"; return; }
  # stop " / die " のメッセージ(複数行もある)ごとに、$ を含まない最長の部分の先頭 15 文字を取り出す
  while IFS= read -r key; do
    n=$((n+1))
    grep -qF -- "$key" "$guide" || fail "leader-guide.md にメッセージがありません: $key"
  done < <(perl -CSDA -0777 -ne '
    while (/(?:^|[^a-z_])(?:stop|die) "([^"]*)"/g) {
      my $m = $1;
      my ($best) = sort { length($b) <=> length($a) } split /[$][(][^)]*[)]|[$][{][^}]*[}]|[$][*]|[$][A-Za-z_]+/, $m;
      next unless defined $best;
      $best =~ s/^[[:space:]]+//;
      $best =~ s/[[:space:]]+$//;
      print substr($best, 0, 15) . chr(10) if length $best;
    }' "$TEMPLATE_ROOT"/scripts/*.sh)
  [ "$n" -gt 0 ] || fail "メッセージを 1 つも取り出せませんでした"
}

test_update_command_paths_exist() {
  local guide="$TEMPLATE_ROOT/docs/git/leader-guide.md" line p n=0
  [ -f "$guide" ] || { fail "docs/git/leader-guide.md がありません"; return; }
  while IFS= read -r line; do
    for p in ${line#*git checkout FETCH_HEAD -- }; do
      n=$((n+1))
      [ -e "$TEMPLATE_ROOT/$p" ] || fail "更新コマンドのパスがテンプレートにありません: $p"
    done
  done < <(grep 'git checkout FETCH_HEAD -- ' "$guide")
  [ "$n" -gt 0 ] || fail "leader-guide.md に更新コマンドがありません"
}
