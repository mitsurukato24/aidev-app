---
name: wf-design
description: Run only the 設計 (design) node of the delivery workflow — produce a reviewable design (scope, impact, approach, acceptance criteria) into the issue's status.json via the wf-designer sub-agent. Use to design a task without implementing yet.
---

# 設計ノード

ワークフローの第1ノード。実装はしない。全体像は [.claude/rules/WORKFLOW.md]。

1. status.json が無ければ作成（必須スクリプト）:
   `bash .claude/skills/wf/scripts/new-status.sh "<タスク名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. `Agent(subagent_type: "wf-designer")` にタスクと status.json パスを渡す。エージェントが
   「1. 設計」節（目的/スコープ/影響範囲/方針/受入基準/リスク）を埋める。
3. 完了後 commit: `設計: <タスク名> (#NN)`。
4. 受入基準と未確定事項を日本語で要約報告。予算超過リスクは PM 判断としてユーザーへ。

## 必須チェックリスト（省略不可）
- [ ] `docs/issues/<issue_name>/status.json` が存在し「1. 設計」節を埋めた
- [ ] スコープ / 影響範囲 / 受入基準 / 関連 Issue・要件 ID を記載
- [ ] commit: `設計: <タスク名> (#NN)`
