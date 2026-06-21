#!/usr/bin/env bash
# Issue の作業フォルダ（worktree）を後片付けする。PR マージ後に呼ぶ。
#   使い方: finish-worktree.sh <issue_name> [issue番号] [--force]
# - .worktree/<issue_name> を git worktree remove（未コミットがあると失敗 → --force で破棄）
# - GitHub Issue から in-progress ラベルを外す（issue 番号を渡したとき・外向き操作）
# ブランチ自体は PR マージ側で削除される想定（ローカルブランチが残れば手動で git branch -d）。
# 通常は PR マージ後＝worktree は clean なはず。--force は未コミットを捨てるので注意。
# - 楽観ロック（new-worktree.sh の claim）を「✅ done」コメントで解放する（issue 番号がある時・best-effort）
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# メインの作業ツリー root。--show-toplevel は「現在の」worktree を返すため、リンク worktree 内の
# cwd から呼ぶと worktree 側を指し、$ROOT/$WORKTREE_DIR/$NAME がパス二重化する（#194）。
# 全 worktree で共有される git-common-dir(<main>/.git) の親＝必ずメイン root に解決する。
ROOT="$(cd "$HERE" && cd "$(git rev-parse --git-common-dir)/.." && pwd)"
LIB="$(cd "$HERE/../../lib" && pwd)"
WORKTREE_DIR="$(python3 "$LIB/config.py" get paths.worktree_dir)"; WORKTREE_DIR="${WORKTREE_DIR:-.worktree}"

# 楽観ロックの worker ID（new-worktree.sh と同じ解決規則）。done コメントの突合に使う。
worker_id() {
  if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then echo "$CLAUDE_CODE_SESSION_ID";
  else echo "$(hostname)-$$-${RANDOM}"; fi
}
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
NAME=""; ISSUE=""; FORCE=""
for a in "$@"; do
  case "$a" in
    --force) FORCE="--force" ;;
    *) if [[ -z "$NAME" ]]; then NAME="$a"; else ISSUE="$a"; fi ;;
  esac
done
[[ -n "$NAME" ]] || { echo "issue_name を指定してください" >&2; exit 2; }
WT="$ROOT/$WORKTREE_DIR/$NAME"

if git -C "$ROOT" worktree list --porcelain | grep -q "$WT"; then
  git -C "$ROOT" worktree remove $FORCE "$WT" && echo "removed worktree: $WT"
else
  echo "worktree が見つかりません: $WT（既に削除済みか）" >&2
fi

if [[ -n "$ISSUE" ]] && command -v gh >/dev/null 2>&1; then
  gh issue edit "$ISSUE" --remove-label in-progress >/dev/null 2>&1 || true
  echo "removed in-progress label from #$ISSUE"
  # 楽観ロックの解放（best-effort）: new-worktree.sh の claim を「✅ done」で無効化する。
  gh issue comment "$ISSUE" --body "✅ done worker=$(worker_id) ts=$(now_iso)" >/dev/null 2>&1 || true
fi
