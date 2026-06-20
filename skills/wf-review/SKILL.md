---
name: wf-review
description: Run only the レビュー (review) node of the delivery workflow — adversarially review the diff for correctness, reuse, efficiency, convention and security/license compliance via the wf-reviewer sub-agent, recording findings with severity in the issue status.json.
---

# レビューノード

ワークフローの第4ノード。検証 PASS 後に実行する。全体像は [.claude/rules/WORKFLOW.md]。

1. `Agent(subagent_type: "wf-reviewer")` に status.json パスを渡す。エージェントは diff
   （`git diff main...HEAD` または作業ツリー差分）を観点別（正確性/再利用/効率/規約/安全・ライセンス）
   にレビューし、「4. レビュー」節へ `file:line`＋重大度で記録する。
2. 重大度・高の指摘があれば実装（wf-implement）→検証（wf-verify、`run-checks.sh` 再 PASS）へ戻す。
   解消後 commit: `レビュー対応: <タスク名> (#NN)`（指摘対応の差分を含む）。
3. 重大度別の件数と承認可否を日本語で報告。承認可なら MR ノード（wf-mr）へ。

## 必須チェックリスト（省略不可）
- [ ] 観点別レビューを「4. レビュー」節へ `file:line`＋重大度で記録
- [ ] 重大度・高はすべて解消（解消後 **`run-checks.sh` を再 PASS**）
- [ ] 高の指摘があった場合のみ commit: `レビュー対応: <タスク名> (#NN)`

補足: より深い多エージェントレビューが要るときは builtin の `/code-review ultra` を併用してよい。
