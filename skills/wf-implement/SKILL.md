---
name: wf-implement
description: Run only the 実装 (implementation) node of the delivery workflow — write the code for an approved design via the wf-implementer sub-agent, then commit. Requires an issue status.json with a filled design section.
---

# 実装ノード

ワークフローの第2ノード。設計済みの status.json を入力にする。全体像は [.claude/rules/WORKFLOW.md]。

1. `docs/issues/<issue_name>/status.json` の「1. 設計」が埋まっていることを確認。
2. `Agent(subagent_type: "wf-implementer")` に status.json パスを渡す。エージェントが受入基準を満たす
   よう実装し、「2. 実装」節（変更ファイル/メモ/TODO）を埋める。規約は [.claude/rules/CODING.md]。
3. 完了後 commit: `実装: <タスク名> (#NN)`。
4. 変更ファイルと受入基準の充足状況を日本語で要約報告。続けて検証ノード（wf-verify）へ。

## 必須チェックリスト（省略不可）
- [ ] 「1. 設計」の受入基準を満たす実装
- [ ] 規約順守（[.claude/rules/CODING.md]）。「2. 実装」節に変更ファイルを記載
- [ ] commit: `実装: <タスク名> (#NN)`（この後、検証ノードで `run-checks.sh` を必ず実行）
