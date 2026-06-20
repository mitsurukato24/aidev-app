---
name: runtime-verify
description: 動作検証 — 鍵なし(mock/dev)でアプリを実起動し、変更したフローを E2E で実際に動かして証跡（コマンド/出力/スクショ）を残す専用 Skill。lint/test(run-checks) とは別の「本当に動くか」を担う。駆動エージェントは runtime-verifier。引数 = 検証対象フロー（例「dev-login→ロードマップ取得」+ issue番号 任意）。
---

# 動作検証（runtime-verify）

「テストが緑」ではなく「**本当に動くか**」を確かめる専用ノード。鍵なし（mock / dev）で完結し決定的に
動くこと。駆動エージェントは `runtime-verifier`。全体像は [.claude/rules/WORKFLOW.md]。起動方法・健全性
判定・dev フラグ・mock 条件はすべて **`.claude/config.json` の `runtime_verify` 由来**（スタック/起動先を
直書きしない）。lint/test は別ノード（`run-checks.sh`）が担う。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<検証フロー名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **実起動＆フロー実行** — `Agent(subagent_type: "runtime-verifier")` に対象と status.json パスを渡す。
   エージェントは `config.runtime_verify`（`launch` / `health` / `docs` / `dev_define` / `mock_mode`）に
   従い**鍵なしで起動**し、**変更したフローを E2E で実際に操作**して（エンドポイントを順に叩く／画面を
   状態遷移させる）、証跡（コマンド・出力・可能ならスクショ）を「3. 検証」節へ記録する。
3. **受入確認**: 受入基準を**実挙動**で満たすことを確認（薄い smoke で済ませない）。NG なら実装へ差し戻す
   （手戻り＝metrics の loopback）。
4. **commit**: `検証: <検証フロー名> (#NN)`（接頭辞は config.commit_prefixes の verify="検証"）。
5. 起動コマンド・操作フロー・観測出力／スクショパス・受入結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **鍵なし（mock / dev）で起動**できる（`runtime_verify` 由来・秘密不要で決定的に通る）
- [ ] **変更フローを実際に操作**（E2E）— smoke ping で済ませない
- [ ] **証跡を残す**（起動＋操作コマンド・観測出力・可能ならスクショ）を「3. 検証」節へ記録
- [ ] **受入基準を実挙動で確認**（薄すぎない）／NG は実装へ差し戻し
- [ ] commit: `検証: <検証フロー名> (#NN)`

補足: これは `run-checks.sh`（lint/test）を置き換えない補完。複雑な場合は wf ワークフローの検証ノードに
組み込んでよい。
