---
name: ci
description: CI保守 — CI パイプラインの保守・コスト最適化を config.deploy.ci（無料枠/重い消費源）を踏まえて行う専用 Skill。駆動エージェントは deployer。ゲート（テスト/カバレッジ）を弱めず、path-filter/concurrency 等で節約し、変更後 CI が緑であること。引数 = CI 改修内容（例「E2E を path-filter で節約」+ issue番号 任意）。
---

# CI保守（ci）

CI パイプラインの保守とコスト最適化を行う専用ノード。駆動エージェントは `deployer`。全体像は
[.claude/rules/WORKFLOW.md]。CI プロバイダ・無料枠・重い消費源・節約方針はすべて
**`.claude/config.json` の `deploy.ci`（`provider` / `free_minutes` / `notes`）由来**（直書きしない）。
CI が実行するチェックは config の `components[].checks` と同一（`run-checks.sh` が解決する）。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<CI 改修名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **改修** — `Agent(subagent_type: "deployer")` に内容と status.json パスを渡す。エージェントは
   `config.deploy.ci`（無料枠 / 重い消費源 = E2E 等 / 節約ヒント）を踏まえ、**ゲート（テスト/カバレッジ）を
   弱めずに** path-filter（変更領域のみ実行）／concurrency（古い run をキャンセル）／draft-skip 等で消費を
   節約する。秘密は環境変数 / CI シークレット経由のみ。
3. **検証**: ローカルで `bash .claude/skills/wf-verify/scripts/run-checks.sh`（CI と同じ config 駆動の
   checks）が **RESULT: PASS**、push 後に **CI が緑**であることを確認し「3. 検証」節へ記録する。
4. **commit**: `<種別>: <CI 改修名> (#NN)`（実装相当なら implement="実装"、検証なら verify="検証" 等、
   config.commit_prefixes の標準接頭辞を用いる）。
5. 変更ファイル・節約手法・ゲートを弱めていない根拠・CI 緑を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **`config.deploy.ci`（無料枠 / 重い消費源）を踏まえる**
- [ ] **ゲート（テスト/カバレッジ）を弱めない**（`components[].checks` の閾値を下げない）
- [ ] **path-filter / concurrency 等で節約**（消費を減らす）
- [ ] **`run-checks.sh` が RESULT: PASS** かつ **変更後 CI が緑**
- [ ] commit: config.commit_prefixes の標準接頭辞（例 `実装: <CI 改修名> (#NN)`）

複雑な場合は wf ワークフローのノードに組み込んでよい。
