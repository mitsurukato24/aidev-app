#!/usr/bin/env bash
# 全 Skill（または指定 Skill）の自動評価を回す＝作業忠実度のデグレ確認・精度評価。
# Skill（SKILL.md / agent / scripts）を修正したら必ず実行する。
#   使い方: run-evals.sh [<skill> ...]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/eval_runner.py" "$@"
