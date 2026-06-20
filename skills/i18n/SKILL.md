---
name: i18n
description: 多言語化 — UI 文言の多言語パリティ・日英等の混在解消・コンテンツのローカライズ導線を wf-implementer サブエージェントで実装し、検証して commit する。引数 = 対象（例「設定画面の文言を全言語そろえる」+ issue番号 任意）。文言は config.languages.ui_locales 全言語ぶん用意し、生成物でなくソース（config.paths.ui_l10n_dir）を編集。
---

# 多言語化（i18n）

UI 文言の多言語パリティ・混在解消・コンテンツのローカライズ導線を整える、実装ノードの専用バリアント。
駆動エージェントは `wf-implementer`。全体像は [.claude/rules/WORKFLOW.md]。スタック固有の i18n 機構は
直書きせず、**このプロジェクトの規約（[.claude/rules/CODING.md] と [.claude/docs/DESIGN.md]）に従う**
（対応言語・ロケールソースの場所は config 駆動）。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<多言語化対象名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **設計＆実装** — `Agent(subagent_type: "wf-implementer")` に対象と status.json パスを渡す。
   エージェントは文言を **config.languages.ui_locales の全言語ぶん**用意し、**生成物ではなくソース
   （config.paths.ui_l10n_dir のロケールファイル）を編集**し、**ハードコード文字列を残さない**
   （UI に直書きされた文言をキー化する）。規約は [.claude/rules/CODING.md] / [.claude/docs/DESIGN.md]。
3. **検証（必須スクリプト・スタック固有コマンド手打ち禁止）**:
   `bash .claude/skills/wf-verify/scripts/run-checks.sh` で **RESULT: PASS** を確認（キー欠落・未翻訳の
   検出を含む）。NG なら実装へ差し戻す。
4. **commit**: `実装: <多言語化対象名> (#NN)`（接頭辞は config.commit_prefixes の implement="実装"）。
5. 変更ファイル・対応言語・追加/補完したキー・残ハードコードの有無・検証結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] 文言は **config.languages.ui_locales の全言語ぶん**用意（パリティを満たす）
- [ ] **生成物でなくソース（config.paths.ui_l10n_dir）を編集**（生成済みファイルを手で触らない）
- [ ] **ハードコード文字列を残さない**（UI 直書きの文言をキー化）
- [ ] **キー欠落の検出**（言語間の不一致・未翻訳キーが残っていない）
- [ ] **`run-checks.sh` が RESULT: PASS**（スタック固有コマンド手打ち禁止）
- [ ] commit: `実装: <多言語化対象名> (#NN)`

複雑な場合は wf ワークフローのノードとして組み込んでよい。
