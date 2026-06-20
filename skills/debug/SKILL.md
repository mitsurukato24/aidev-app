---
name: debug
description: デバッグ — バグの再現→切り分け→根本原因特定→修正を wf-implementer サブエージェントで行い、検証して commit する。引数 = 不具合の説明（例「ログイン後に白画面」+ issue番号 任意）。症状でなく**根本原因**を特定し、**再発防止のリグレッションテスト**を必ず追加する。
---

# デバッグ

バグを再現→切り分け→根本原因特定→修正する、実装ノードの専用バリアント。駆動エージェントは
`wf-implementer`。全体像は [.claude/rules/WORKFLOW.md]。スタック固有のテスト/実行コマンドは直書きせず、
**このプロジェクトの規約（[.claude/rules/CODING.md] と [.claude/docs/DESIGN.md]）に従う**（再現/検証の
コマンドは config 駆動）。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<不具合名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **再現＆修正** — `Agent(subagent_type: "wf-implementer")` に症状と status.json パスを渡す。
   エージェントは**再現手順を記録**し、**症状でなく根本原因を特定**して修正し、**再発防止の
   リグレッションテストを追加**する（修正前は赤・修正後は緑になるテスト）。規約は
   [.claude/rules/CODING.md] / [.claude/docs/DESIGN.md]。
3. **検証（必須スクリプト・スタック固有コマンド手打ち禁止）**:
   `bash .claude/skills/wf-verify/scripts/run-checks.sh` で **RESULT: PASS** を確認。NG なら実装へ
   差し戻す。
4. **commit**: `実装: <不具合名> (#NN)`（接頭辞は config.commit_prefixes の implement="実装"）。
5. 再現手順・根本原因・修正内容・追加したリグレッションテスト・検証結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **再現手順を記録**（status.json に再現条件を残す）
- [ ] 症状でなく**根本原因を特定**（対症療法でふさがない）
- [ ] **再発防止のリグレッションテストを追加**（修正前は失敗・修正後は成功）
- [ ] **`run-checks.sh` が RESULT: PASS**（スタック固有コマンド手打ち禁止）
- [ ] commit: `実装: <不具合名> (#NN)`

複雑な場合は wf ワークフローのノードとして組み込んでよい。
