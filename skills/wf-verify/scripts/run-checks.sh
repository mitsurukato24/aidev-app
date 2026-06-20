#!/usr/bin/env bash
# 検証ノードの定型チェックをまとめて実行する（config 駆動・スタック非依存）。
# .claude/config.json の components[].checks を読み、変更があった component だけ lint/test を走らせる。
# スタック(pytest/flutter/…)は直書きしない＝別プロジェクトは config を差し替えるだけで動く。
# 鍵なし(mock/dev)で完結する前提。引数 --all で全 component を強制実行。
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)"   # .claude/skills/lib
ROOT="$(python3 "$LIB/config.py" root)"
cd "$ROOT"

FORCE_ALL=0
[[ "${1:-}" == "--all" ]] && FORCE_ALL=1

DEFAULT_BRANCH="$(python3 "$LIB/config.py" get vcs.default_branch)"; DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# 変更領域の検出（ステージ/未ステージ/default branch との差分を合算）。
CHANGED="$(git diff --name-only; git diff --name-only --staged; git diff --name-only "${DEFAULT_BRANCH}...HEAD" 2>/dev/null)"

CHECKS="$(python3 "$LIB/config.py" checks)"
[[ -n "$CHECKS" ]] || { echo "config.json に components[].checks がありません" >&2; exit 2; }

# どの component が変更されたか（path 接頭辞一致）
declare -A COMP_CHANGED
any_changed=0
while IFS=$'\t' read -r comp path label cwd cmd gate envunset; do
  [[ -z "$comp" ]] && continue
  if [[ -n "$path" ]] && grep -q "^${path}" <<<"$CHANGED"; then
    COMP_CHANGED["$comp"]=1; any_changed=1
  fi
done <<<"$CHECKS"

rc=0
ran=0
while IFS=$'\t' read -r comp path label cwd cmd gate envunset; do
  [[ -z "$comp" || -z "$cmd" ]] && continue
  # 実行可否: --all か / 変更検出ゼロ(安全側で全実行) か / この component が変更された
  run=0
  if [[ $FORCE_ALL -eq 1 || $any_changed -eq 0 ]]; then run=1
  elif [[ -n "${COMP_CHANGED[$comp]:-}" ]]; then run=1; fi
  [[ $run -eq 1 ]] || continue
  ran=1
  echo "==== ${comp}: ${label}${gate:+ (coverage gate >=${gate}%)} ===="
  (
    cd "$ROOT/${cwd:-.}" || exit 1
    for v in ${envunset//,/ }; do unset "$v" 2>/dev/null || true; done
    eval "$cmd"
  ) || rc=1
done <<<"$CHECKS"

echo "===================================="
[[ $ran -eq 1 ]] || echo "（実行対象の component なし）"
if [[ $rc -eq 0 ]]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $rc
