#!/usr/bin/env bash
# Issue ごとの作業を開始する: .worktree/<issue_name>/ に git worktree を作り、その中に
# status.json を起こし、GitHub Issue に「作業開始」を可視化する。同一 Issue の二重作業を防ぐ。
#   使い方: new-worktree.sh "<タスク名>" [issue番号] [種別: 標準|content|ui] [--force]
# 出力(stdout): WORKTREE=<path> / STATUS=<status.json path> / BRANCH=<branch>
# 以降の全ノードは WORKTREE の中で作業し、コミットは BRANCH に積む。完了後は finish-worktree.sh。
#
# 二重作業ガードは多層防御:
#   ① ローカル branch/worktree の一意性（hard lock・既存なら exit 1）
#   ② GitHub の in-progress ラベル（cross-machine の advisory lock）
#   ③ GitHub コメントの全順序を使った楽観ロック（claim 投稿→read-back→最小 id が勝つ）
# ③ は TOCTOU（②のラベル check→set が非アトミックで残る競合ウィンドウ）を埋めるためのもの。
# worktree/branch の作成は ①②③ をすべて通過した「勝者」だけが行う＝敗者はファイル副作用ゼロ。
#
# テスト容易性: gh 呼び出しは薄いラッパ関数（gh_api_comments / gh_post_comment）に集約し、
# ロック本体（parse_active_claims / decide_winner / acquire_comment_lock）を純粋関数寄りに分割。
# WF_LOCK_DRYRUN=1 で gh を叩かずモック（環境変数 _MOCK_COMMENTS）で勝敗ロジックを単体検証できる。
set -euo pipefail

# --- 可変パラメータ（環境変数で上書き可・既定はそのまま運用） ---
LOCK_READBACK_SLEEP="${LOCK_READBACK_SLEEP:-1.5}"   # claim 投稿後 read-back までの待ち（秒）
LOCK_READBACK_RETRY="${LOCK_READBACK_RETRY:-5}"     # 自分の claim が見えるまでの最大リトライ回数
LOCK_CONVERGE_SLEEP="${LOCK_CONVERGE_SLEEP:-$LOCK_READBACK_SLEEP}"  # 勝者確定前の収束 re-read 待ち（秒）
LOCK_TTL_HOURS="${LOCK_TTL_HOURS:-6}"               # claim の有効期限（h）。超過した未解放 claim は stale
WF_LOCK_DRYRUN="${WF_LOCK_DRYRUN:-0}"               # 1 なら gh を叩かずモック動作（テスト用）

# 機械可読な claim フォーマットの接頭辞（grep/parse の固定キー）
CLAIM_TAG="🔒 claim"
YIELD_TAG="🤝 yield"
DONE_TAG="✅ done"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# メインの作業ツリー root（finish-worktree.sh と同じ堅牢解決・#194）。--show-toplevel は現在の
# worktree を返すため、リンク worktree 内から呼ぶと作成先が二重化しうる。git-common-dir の親で固定。
ROOT="$(cd "$HERE" && cd "$(git rev-parse --git-common-dir)/.." && pwd)"
LIB="$(cd "$HERE/../../lib" && pwd)"
# 配置(worktree_dir)とブランチ元(default_branch)は config 由来＝プロジェクト非依存
WORKTREE_DIR="$(python3 "$LIB/config.py" get paths.worktree_dir)"; WORKTREE_DIR="${WORKTREE_DIR:-.worktree}"
DEFAULT_BRANCH="$(python3 "$LIB/config.py" get vcs.default_branch)"; DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# ---------------------------------------------------------------------------
# 引数パース
# ---------------------------------------------------------------------------
TITLE=""; ISSUE=""; KIND="標準"; FORCE=0
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    *) if [[ -z "$TITLE" ]]; then TITLE="$a";
       elif [[ "$a" =~ ^[0-9]+$ && -z "$ISSUE" ]]; then ISSUE="$a";
       else KIND="$a"; fi ;;
  esac
done
[[ -n "$TITLE" ]] || { echo "タスク名を指定してください" >&2; exit 2; }

# ---------------------------------------------------------------------------
# worker ID: $CLAUDE_CODE_SESSION_ID を主、未設定なら hostname-pid-rand で合成
# ---------------------------------------------------------------------------
worker_id() {
  if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
    echo "$CLAUDE_CODE_SESSION_ID"
  else
    echo "$(hostname)-$$-${RANDOM}"
  fi
}
WORKER_ID="$(worker_id)"

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ---------------------------------------------------------------------------
# gh 薄いラッパ（テスト時に DRY_RUN で差し替え可能にするための分離点）
# ---------------------------------------------------------------------------

# owner/repo を "owner/repo" 形式で返す（REST のパス組み立て用）
gh_repo_slug() {
  if [[ "$WF_LOCK_DRYRUN" == "1" ]]; then echo "${_MOCK_REPO:-owner/repo}"; return 0; fi
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null
}

# issue の全コメントを「<id>\t<body一行化>」の TSV で標準出力に流す。
# 失敗時は非ゼロ終了（呼び出し側が degrade 判定する）。
# REST を使う理由: `gh issue view --json comments` は数値 id を返さないため、全順序キーに使えない。
gh_api_comments() {
  local issue="$1"
  if [[ "$WF_LOCK_DRYRUN" == "1" ]]; then
    # テスト用: _MOCK_COMMENTS に "<id>\t<body>" 改行区切りで与える。
    # _MOCK_COMMENTS_2 を与えると 2 回目以降の取得でそちらを返す（収束 re-read で
    # 「2 回目に自分より小さい id が出現」する競合シナリオを再現できる）。呼び出しは
    # コマンド置換（サブシェル）越しなので、回数カウンタは _MOCK_CALLS_FILE に永続させる。
    if [[ -n "${_MOCK_COMMENTS_2:-}" && -n "${_MOCK_CALLS_FILE:-}" ]]; then
      local n; n="$(cat "$_MOCK_CALLS_FILE" 2>/dev/null || echo 0)"
      n=$(( n + 1 )); printf '%s' "$n" > "$_MOCK_CALLS_FILE"
      if [[ "$n" -ge 2 ]]; then printf '%s\n' "$_MOCK_COMMENTS_2"; return 0; fi
    fi
    printf '%s\n' "${_MOCK_COMMENTS:-}"
    return 0
  fi
  local slug; slug="$(gh_repo_slug)" || return 1
  [[ -n "$slug" ]] || return 1
  # body 内の改行は parse を壊すので空白へ畳む。--paginate で全コメントを取得。
  gh api --paginate "repos/${slug}/issues/${issue}/comments" \
    --jq '.[] | "\(.id)\t\(.body | gsub("[\r\n]+";" "))"' 2>/dev/null || return 1
}

# コメントを投稿する。best-effort（失敗しても着手はブロックしない）。
gh_post_comment() {
  local issue="$1" body="$2"
  if [[ "$WF_LOCK_DRYRUN" == "1" ]]; then
    echo "[dryrun] post #${issue}: ${body}" >&2
    return 0
  fi
  gh issue comment "$issue" --body "$body" >/dev/null 2>&1 || return 1
}

# ---------------------------------------------------------------------------
# 純粋寄りのロックロジック（標準入力で TSV コメントを受け、有効 claim を算出）
# ---------------------------------------------------------------------------

# TTL 超過判定: ts(UTC ISO) が now-TTL より古ければ 0(=stale) を返す
_ts_is_stale() {
  local ts="$1" ttl_sec epoch_ts epoch_cut
  ttl_sec=$(( LOCK_TTL_HOURS * 3600 ))
  epoch_ts="$(date -u -d "$ts" +%s 2>/dev/null || echo 0)"
  [[ "$epoch_ts" == "0" ]] && return 1   # パース不能なら stale 扱いしない（安全側）
  epoch_cut=$(( $(date -u +%s) - ttl_sec ))
  [[ "$epoch_ts" -lt "$epoch_cut" ]]
}

# 標準入力(TSV: id\tbody) から「有効な claim」を "<id>\t<worker>" で id 昇順出力する。
# 有効＝(a) claim 行で worker/ts をパースでき (b) 同一 worker の done/yield が後に無く
#       (c) TTL 超過でない もの。done/yield で解放済み worker と stale を除外する。
parse_active_claims() {
  local lines; lines="$(cat)"
  # done/yield 済みの worker 集合を先に収集
  local released
  released="$(awk -F'\t' -v dy="$DONE_TAG|$YIELD_TAG" '
    {
      body=$2
      if (match(body, /(✅ done|🤝 yield) worker=[^ ]+/)) {
        s=substr(body, RSTART, RLENGTH)
        sub(/.*worker=/, "", s)
        print s
      }
    }' <<<"$lines")"

  # claim 行を id 昇順で（REST はおおむね昇順だが念のため sort -n）
  while IFS=$'\t' read -r id body; do
    [[ -z "$id" ]] && continue
    [[ "$body" == *"$CLAIM_TAG"* ]] || continue
    # worker= と ts= を抽出
    local w ts
    w="$(sed -n 's/.*worker=\([^ ]*\).*/\1/p' <<<"$body")"
    ts="$(sed -n 's/.*ts=\([^ ]*\).*/\1/p' <<<"$body")"
    [[ -n "$w" ]] || continue
    # 解放済み worker は除外
    grep -qxF "$w" <<<"$released" && continue
    # TTL 超過は除外
    if [[ -n "$ts" ]] && _ts_is_stale "$ts"; then continue; fi
    printf '%s\t%s\n' "$id" "$w"
  done <<<"$lines" | sort -n -k1,1
}

# 有効 claim 集合（"<id>\t<worker>" を標準入力）から勝者 worker を返す＝最小 id の worker。
decide_winner() {
  head -n1 | cut -f2
}

# 有効 claim 集合（"<id>\t<worker>" を標準入力）に、指定 worker の claim が含まれるか。
# worker_id をリテラル（正規表現でなく文字列 == 比較）で判定する＝メタ文字混入でも取りこぼさない。
has_active_claim() {
  local target="$1"
  awk -F'\t' -v w="$target" '$2 == w { found=1 } END { exit (found ? 0 : 1) }'
}

# ---------------------------------------------------------------------------
# 楽観ロック取得: claim 投稿 → read-back（自分の claim が見えるまでリトライ）→ 勝敗判定。
# 戻り値: 0=勝者（着手してよい） / 1=敗者（yield 済み・着手しない） / 2=degrade（gh 失敗で skip）
# ---------------------------------------------------------------------------
acquire_comment_lock() {
  local issue="$1"

  # claim 投稿（失敗したら degrade）
  if ! gh_post_comment "$issue" "${CLAIM_TAG} worker=${WORKER_ID} ts=$(now_iso) name=${NAME}"; then
    echo "⚠ claim コメント投稿に失敗。コメントロックを skip し従来ラベル方式で続行します。" >&2
    return 2
  fi

  # read-after-write の eventual consistency 緩和: sleep + 自分の claim が見えるまでリトライ
  local attempt comments winner active
  for (( attempt=1; attempt<=LOCK_READBACK_RETRY; attempt++ )); do
    sleep "$LOCK_READBACK_SLEEP" 2>/dev/null || true
    if ! comments="$(gh_api_comments "$issue")"; then
      echo "⚠ コメント取得(REST)に失敗。コメントロックを skip し従来ラベル方式で続行します。" >&2
      return 2
    fi
    # 自分の有効 claim が read-back に現れたか（worker_id はリテラル比較）
    active="$(printf '%s\n' "$comments" | parse_active_claims)"
    if printf '%s\n' "$active" | has_active_claim "$WORKER_ID"; then
      winner="$(printf '%s\n' "$active" | decide_winner)"
      if [[ "$winner" != "$WORKER_ID" ]]; then
        # 他人が先（より小さい id）。譲って exit。
        echo "Issue #${issue} は他のワーカー(${winner})が先に claim 済み。yield して中断します。" >&2
        gh_post_comment "$issue" "${YIELD_TAG} worker=${WORKER_ID} ts=$(now_iso)" || true
        return 1
      fi

      # ── 収束 re-read（最重要）─────────────────────────────────────────────
      # 「自分の claim は見えたが、ほぼ同時の相手のより小さい id がまだ伝播していない」
      # 窓を閉じるため、勝者と即断せず もう一度（短い sleep 後に）全コメントを取り直し、
      # 有効 claim 集合の最小 id を再判定する。
      # ・再判定でも最小 id が自分 → 勝者＝続行（return 0）
      # ・自分より小さい有効 claim が現れた → 敗者として yield して exit 1
      # ・収束 re-read 自体が失敗 → 既存 degrade（rc=2 で着手継続）に倣う
      sleep "$LOCK_CONVERGE_SLEEP" 2>/dev/null || true
      local comments2 active2 winner2
      if ! comments2="$(gh_api_comments "$issue")"; then
        echo "⚠ 収束 re-read(REST)に失敗。コメントロックを skip し従来ラベル方式で続行します。" >&2
        return 2
      fi
      active2="$(printf '%s\n' "$comments2" | parse_active_claims)"
      # 収束 re-read で自分の claim が消えていたら（整合性遅延）安全側で degrade。
      if ! printf '%s\n' "$active2" | has_active_claim "$WORKER_ID"; then
        echo "⚠ 収束 re-read で自分の claim が見えませんでした（整合性遅延）。ラベル多層防御に委ね続行します。" >&2
        return 2
      fi
      winner2="$(printf '%s\n' "$active2" | decide_winner)"
      if [[ "$winner2" == "$WORKER_ID" ]]; then
        return 0   # 収束後も最小 id が自分＝確定勝者
      fi
      # 収束で自分より小さい id の有効 claim が出現＝敗者。
      echo "Issue #${issue} は他のワーカー(${winner2})の claim が収束 re-read で先着判明。yield して中断します。" >&2
      gh_post_comment "$issue" "${YIELD_TAG} worker=${WORKER_ID} ts=$(now_iso)" || true
      return 1
    fi
    # まだ自分の claim が見えない→次のリトライ
  done

  # リトライ尽きても自分の claim が見えない＝整合性遅延。安全側で degrade（着手はブロックしない）。
  echo "⚠ 自分の claim が read-back に現れませんでした（整合性遅延）。ラベル多層防御に委ね続行します。" >&2
  return 2
}

# ---------------------------------------------------------------------------
# 本処理
# ---------------------------------------------------------------------------
NAME="$(python3 "$HERE/status.py" name "$TITLE" ${ISSUE:+--issue "$ISSUE"})"
WT="$ROOT/$WORKTREE_DIR/$NAME"
BRANCH="$NAME"

# ① 二重作業ガード（ローカル: ブランチ/worktree の一意性が hard lock） ---
if [[ -d "$WT" ]] || git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "既に作業中（worktree かブランチが存在）: $BRANCH" >&2
  echo "  既存に入るなら: cd $WT" >&2
  exit 1
fi

# ② 二重作業ガード（GitHub: in-progress ラベルで cross-machine の advisory lock） ---
if [[ -n "$ISSUE" ]] && command -v gh >/dev/null 2>&1; then
  LABELS="$(gh issue view "$ISSUE" --json labels -q '.labels[].name' 2>/dev/null || true)"
  if grep -qx 'in-progress' <<<"$LABELS" && [[ $FORCE -eq 0 ]]; then
    echo "Issue #$ISSUE は既に in-progress（別の作業が進行中の可能性）。続けるなら --force。" >&2
    exit 1
  fi
fi

# ③ 二重作業ガード（GitHub: コメント全順序の楽観ロック） ---
# worktree/branch を作る前に勝敗を確定させる＝敗者はファイル副作用ゼロ。
# issue 番号が無い／gh 不在は skip（従来挙動）。--force は楽観ロックも上書き着手。
if [[ -n "$ISSUE" ]] && command -v gh >/dev/null 2>&1 && [[ $FORCE -eq 0 ]]; then
  set +e
  acquire_comment_lock "$ISSUE"
  rc=$?
  set -e
  case "$rc" in
    0) : ;;                       # 勝者→続行
    1) exit 1 ;;                  # 敗者→yield 済み・着手しない（worktree 未作成）
    2) : ;;                       # degrade→ラベル多層防御に委ねて続行
  esac
fi

# --- ここから先は「勝者」だけが到達する ---

# --- worktree 作成（default_branch から新ブランチ） ---
git -C "$ROOT" worktree add "$WT" -b "$BRANCH" "$DEFAULT_BRANCH" >/dev/null
# --- worktree 内に status.json ---
STATUS="$(python3 "$WT/.claude/skills/wf/scripts/status.py" new "$TITLE" ${ISSUE:+--issue "$ISSUE"} --type "$KIND")"

# --- GitHub: 作業開始を可視化（外向き操作・best-effort） ---
if [[ -n "$ISSUE" ]] && command -v gh >/dev/null 2>&1; then
  gh label create in-progress --color FBCA04 --description "作業中（同一Issueの二重作業防止の目印）" >/dev/null 2>&1 || true
  gh issue edit "$ISSUE" --add-label in-progress >/dev/null 2>&1 || true
  gh issue comment "$ISSUE" --body "🚧 作業開始: ブランチ \`$BRANCH\` / worktree \`$WORKTREE_DIR/$NAME\`（進捗は status.json で管理）" >/dev/null 2>&1 || true
fi

echo "WORKTREE=$WT"
echo "STATUS=$STATUS"
echo "BRANCH=$BRANCH"
