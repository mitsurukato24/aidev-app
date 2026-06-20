---
name: wf
description: Run the full solo-leveling delivery workflow for a task — 設計 → 実装 → 検証(Lint/Test/動作確認) → レビュー → MR — each node driven by a specialized sub-agent, committing after each node. Use when the user hands you a feature/fix/task to take end-to-end. Args = the task description (and optionally an issue number).
---

# 標準デリバリーワークフロー（オーケストレータ）

タスクを **設計 → 実装 → 検証 → レビュー → MR** の順に、各ノードを専門 sub エージェントへ委譲して
進める。**全体像と各ノードの必須作業の真実源は [.claude/rules/WORKFLOW.md]**（本書はその運用手順）。
**各ノード完了ごとに commit**（[.claude/rules/GIT.md]）。push / `gh pr create` は外向き操作。

## 手順

0. **優先度判定（PM）**: `gh issue list` でオープン Issue（#1〜#9 等）と突き合わせ優先度を判断。
   今やるべきでない低優先なら、着手せず `gh issue create` で起票して終える。予算超過の恐れは
   ユーザー判断を仰ぐ。進めるなら次へ。

1. **作業開始＝worktree 構築（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-worktree.sh "<タスク名>" [issue番号] [種別: 標準|content|ui]`
   → `.worktree/<issue_name>/` に **専用 git worktree＋ブランチ** を作り、その中に
   `docs/issues/<issue_name>/status.json` を起こし、GitHub Issue に「作業開始」を可視化する。
   - **二重作業防止（多層防御）**: ① 同名ブランチ/worktree があれば失敗（ローカル hard lock）。
     ② Issue に `in-progress` ラベルがあれば中断（cross-machine の advisory lock。続けるなら `--force`）。
     ③ **コメント全順序の楽観ロック**（ラベル check→set の TOCTOU を埋める）: `🔒 claim worker=<id> ts=<UTC>`
     を Issue に投稿→read-back（REST `gh api .../issues/N/comments` の数値 `id` が全順序キー）→
     有効 claim のうち**最小 id が自分なら勝者＝着手**、他人が先なら `🤝 yield` を残して中断（worktree/branch は
     作らない＝副作用ゼロ）。自分の claim が見えても即着手せず**もう一度全コメントを取り直して最小 id を再判定する
     「収束 re-read」**を行い、遅延伝播していた相手のより小さい id を取りこぼさない（真の同時 claim の残留窓は
     低確率で、この収束 re-read＋多層防御=① hard lock／② in-progress ラベルで限定される）。worker ID は
     `$CLAUDE_CODE_SESSION_ID`（未設定時は hostname-pid-rand）。
     done/yield 済み・TTL（既定6h）超過の claim は無効。`gh` 不在/REST 失敗時はラベル方式へ degrade（着手は
     ブロックしない）。`finish-worktree.sh` が `✅ done` で解放。`--force` は楽観ロックも上書き着手。
   - **以降の全ノードはこの worktree の中で作業し、コミットはこのブランチに積む**（main 直コミットしない）。
     `WORKTREE=` のパスへ cd して進める。

2. **設計** — `Agent(subagent_type: "wf-designer")` に status.json パスとタスクを渡す。
   完了後 commit: `設計: <タスク名> (#NN)`。

3. **実装** — `Agent(subagent_type: "wf-implementer")`。完了後 commit: `実装: <タスク名> (#NN)`。

4. **検証** — `Agent(subagent_type: "wf-verifier")`。エージェントは **`run-checks.sh`** を実行する。
   返り値が **FAIL** なら実装(3)へ戻し PASS までループ。PASS 後 commit: `検証: <タスク名> (#NN)`。

5. **レビュー** — `Agent(subagent_type: "wf-reviewer")`。重大度・高の指摘があれば実装(3)→検証(4)へ
   戻す。解消後 commit: `レビュー対応: <タスク名> (#NN)`。

6. **MR** — `Agent(subagent_type: "wf-mr-author")`。エージェントは PR タイトル/本文（日本語、`Closes #NN`、
   検証結果、末尾 trailer）を用意し push（ブランチ）/ `gh pr create`（base `main`）して PR URL を
   status.json へ。**MR ノードはここまで＝マージはしない**。

7. **マージ判断（PM 自身・委譲しない）** — PR 作成後、**PM が**マージ前ゲートを確認する:
   `gh pr checks <PR>` で **CI が緑**、レビュー重大度・高の未解消なし、各ノード commit 済みで作業ツリー
   クリーン。すべて満たせば **PM が `gh pr merge <PR> --squash`** で `main` へ取り込む（満たさなければ
   実装(3)へ差し戻す）。この判断は PM が自走して下す＝ユーザーに可否を仰がない（予算超過の恐れがある場合のみ例外）。
   結果を status.json に記録。

8. **後片付け**: マージ後に
   `bash .claude/skills/wf/scripts/finish-worktree.sh <issue_name> [issue番号]`
   → worktree を撤去し、Issue の `in-progress` ラベルを外す。

9. **次の作業へ（PM 自身・停止しない）** — 1 タスク完了で止まらない。簡潔に完了報告したら、**PM は
   そのまま手順 0 の優先度判定へ戻り**、`gh issue list` で次の最優先タスクを選んで着手する。停止して
   よいのは「残務がない」か escalation 相当（予算超過の恐れ／取り消し困難・品質致命の判断）のときだけ
   ＝完了報告して指示を待つのは禁止。

## 必須チェックリスト（省略不可）

- [ ] `gh issue list` で優先度判定した（低優先は `gh issue create` で起票して終了）
- [ ] `new-worktree.sh` で `.worktree/<issue_name>/` を作り、その中で作業した（main 直コミット禁止）
- [ ] 設計→実装→検証→レビュー→MR の順に進め、**各ノード完了ごとにブランチへ commit** した
- [ ] 各ノードで **メトリクス記録**（`status.py metric --start/--end`、差し戻し時 `--loopback`、
      commit 時 `--artifacts`、トークンは best-effort `--tokens`）＝retro の6観点評価に使う（[QUALITY.md]）
- [ ] 検証は **`run-checks.sh`**（config 駆動）で実行（スタック固有コマンドの手打ち禁止）。FAIL は実装へ差し戻し
- [ ] レビュー重大度・高をすべて解消（解消後 検証を再 PASS）
- [ ] MR ノードは PR 作成まで（push / `gh pr create`）。**マージはしない**
- [ ] **マージは PM が判断**: `gh pr checks` で CI 緑・高指摘なし・commit 済みを確認し `gh pr merge`（委譲しない）
- [ ] マージ後 `finish-worktree.sh` で worktree 撤去・ラベル解除
- [ ] **後片付け後は停止せず優先度判定へ戻り**、次の最優先タスクに着手した（指示待ち禁止）

## 原則
- 各ノードは前ノードが status.json に書いた内容を入力にする。エージェントの返り値（要約）で次へ進む。
- 1 Issue = 1 worktree = 1 ブランチ。並行作業は互いに隔離される。commit はこのスキル（メインループ）が
  worktree 内で行い、sub エージェントには行わせない。
- 対話・報告は日本語で簡潔に。
