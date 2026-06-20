#!/usr/bin/env bash
# docs/issues/<issue_name>/status.json を作成する薄いラッパ（実体は status.py）。
#   使い方: new-status.sh "<タスク名>" [issue番号] [種別: 標準|content|ui]
# 更新は status.py（node / check / commit / set / show）で行う。スキーマ: .claude/templates/status.schema.json
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TITLE="${1:?タスク名を指定してください}"
ISSUE="${2:-}"
KIND="${3:-標準}"
ARGS=("$TITLE" --type "$KIND")
[[ -n "$ISSUE" ]] && ARGS+=(--issue "$ISSUE")
exec python3 "$HERE/status.py" new "${ARGS[@]}"
