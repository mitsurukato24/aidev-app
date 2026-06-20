---
name: wf-mr
description: Run only the MR node of the delivery workflow — prepare and open the merge request (Japanese PR body, Closes #NN, verification summary) via the wf-mr-author sub-agent. Outward-facing — push and gh pr create require confirmation.
---

# MR ノード

ワークフローの最終ノード。検証 PASS かつ重大度・高のレビュー指摘が解消済みであること。
全体像は [.claude/rules/WORKFLOW.md]。

1. 前提確認: 各ノード commit 済み・検証 PASS・高指摘なし。最終確認として
   **`bash .claude/skills/wf-verify/scripts/run-checks.sh`** を再実行し PASS を確かめる。
2. `Agent(subagent_type: "wf-mr-author")` に status.json パスを渡す。エージェントは PR タイトル/本文
   （日本語、`Closes #NN`、検証結果、末尾 Generated trailer）を用意し、「5. MR」節を埋める。
3. base `main` で PR を作成し、PR URL を status.json に記録。**この MR ノードは PR 作成まで＝マージはしない**。
4. PR リンクと CI 期待を日本語で報告。
5. **マージ判断は PM の専管**（[WORKFLOW.md] のマージ判断ノード）。MR 後、**PM が**マージ前ゲート
   （`gh pr checks` で CI 緑・高指摘なし・commit 済み）を確認して `gh pr merge` する。MR ノードはマージしない。

## 必須チェックリスト（省略不可）
- [ ] 全ノード commit 済み・**`run-checks.sh` 再 PASS**・高指摘なし
- [ ] PR 本文は日本語・`Closes #NN`・検証結果・末尾 trailer
- [ ] push / `gh pr create` を実施し、PR URL を「5. MR」節へ記録
- [ ] **マージはしない**。マージ可否は PM が `gh pr merge` で判断（[WORKFLOW.md]）

ルール: [.claude/rules/GIT.md]。
