---
name: refactor
description: リファクタ — レガシー廃止・dead code 掃除・DRY・重複統合を wf-implementer サブエージェントで行い、検証して commit する。引数 = 対象（例「重複する日付整形ロジックを集約」+ issue番号 任意）。**挙動を変えない**（テスト不変で緑）。リリース前なので廃止は**削除**（deprecated 化しない＝TO-BE）。
---

# リファクタ

レガシー廃止・dead code 掃除・DRY・重複統合を行う、実装ノードの専用バリアント。駆動エージェントは
`wf-implementer`。全体像は [.claude/rules/WORKFLOW.md]。スタック固有のツール/コマンドは直書きせず、
**このプロジェクトの規約（[.claude/rules/CODING.md] と [.claude/docs/DESIGN.md]）に従う**（検証コマンドは
config 駆動）。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<リファクタ対象名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **整理＆実装** — `Agent(subagent_type: "wf-implementer")` に対象と status.json パスを渡す。
   エージェントは**挙動を変えず**（既存テストはそのまま緑のまま）に重複を**集約先を明記して統合**し、
   不要になったコードは**削除**する（リリース前なので deprecated 化はしない＝TO-BE）。規約は
   [.claude/rules/CODING.md] / [.claude/docs/DESIGN.md]。
3. **検証（必須スクリプト・スタック固有コマンド手打ち禁止）**:
   `bash .claude/skills/wf-verify/scripts/run-checks.sh` で **RESULT: PASS** を確認（既存テストが
   不変で通る＝挙動が変わっていない証跡）。NG なら実装へ差し戻す。
4. **commit**: `実装: <リファクタ対象名> (#NN)`（接頭辞は config.commit_prefixes の implement="実装"）。
5. 変更ファイル・重複の集約先・削除したコード・挙動不変の根拠（テスト不変）・検証結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **挙動を変えない**（既存テストを変えずに緑のまま＝外部から見た振る舞いは不変）
- [ ] リリース前なので廃止は**削除**（deprecated 化しない＝TO-BE）
- [ ] **重複の集約先を明記**（どこに一本化したかを status.json/報告に残す）
- [ ] **`run-checks.sh` が RESULT: PASS**（スタック固有コマンド手打ち禁止）
- [ ] commit: `実装: <リファクタ対象名> (#NN)`

複雑な場合は wf ワークフローのノードとして組み込んでよい。
