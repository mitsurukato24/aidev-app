---
name: wf-verify
description: Run only the 検証 (Lint / Test / 動作確認) node of the delivery workflow — run the config-driven checks with coverage gates and a deterministic functional check via the wf-verifier sub-agent, recording results in the issue status.json. Bundles run-checks.sh.
---

# 検証ノード（Lint / Test / 動作確認）

ワークフローの第3ノード。鍵なし（mock / dev）で完結すること。全体像は [.claude/rules/WORKFLOW.md]。

**定型作業は必ずスクリプト経由。スタック固有コマンド（`pytest` / `flutter analyze` 等）を手打ちしない**
（`run-checks.sh` が `.claude/config.json` の `components[].checks` から解決する）。

1. `Agent(subagent_type: "wf-verifier")` に status.json パスを渡す。エージェントは必須スクリプト
   **`bash .claude/skills/wf-verify/scripts/run-checks.sh`**（変更 component を検出し各 `checks` を
   `cwd` で実行・`coverage_gate` 強制。`--all` で全 component 強制）を走らせ、`config.runtime_verify`
   に従い**動作確認**を行い、「3. 検証」節へ結果（コマンド / pass-fail / カバレッジ）を記録する。
   - より深い実起動E2Eは `runtime-verify` Skill。ドメイン検証（例: 学習コンテンツ）は当該ドメインSkillの
     チェックスクリプト（`config.domain_skills` 有効時。solo-leveling は `content-gen/scripts/check-content.sh`）。
2. 返り値が **FAIL** なら実装ノード（wf-implement）へ差し戻し（手戻り＝metrics の loopback）。**PASS** なら
   commit: `検証: <タスク名> (#NN)`。
3. PASS/FAIL を日本語で明確に報告する。③網羅性（受入基準を本当に満たすか）も確認＝検証が薄くないこと。

## 必須チェックリスト（省略不可）
- [ ] **`run-checks.sh`** を実行し **RESULT: PASS**（config 駆動・手打ち禁止）
- [ ] 各 component のカバレッジが `coverage_gate` 以上（config 由来）
- [ ] 動作確認（`runtime_verify`）の手順と結果を「3. 検証」節に記録・受入基準を実際に満たす
- [ ] FAIL なら実装へ差し戻し / PASS なら commit: `検証: <タスク名> (#NN)`

補足: 最終判定は CI（`.github/workflows/ci.yml`・config の checks に対応）に従う。
