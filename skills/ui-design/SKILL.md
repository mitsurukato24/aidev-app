---
name: ui-design
description: UIデザイン — このプロジェクトのデザインシステムに準拠して画面/コンポーネントを設計実装する専用 Skill。駆動エージェントは ui-designer。トークン/共有コンポーネント再利用・全 UI ロケールの i18n・状態網羅（通常/空/ローディング/エラー）・検証は run-checks。引数 = 対象画面/コンポーネント（+ issue番号 任意）。
---

# UIデザイン

画面/コンポーネントを**このプロジェクトのデザインシステム**準拠で設計＆実装する専用ノード。駆動
エージェントは `ui-designer`。全体像は [.claude/rules/WORKFLOW.md]。フロントのスタック・デザイントークン・
コンポーネント・i18n の流儀はすべて **[.claude/rules/CODING.md] と [.claude/docs/DESIGN.md] のこの
プロジェクトのデザインシステム / フロント規約に従う**（フレームワーク名/トークン体系を直書きしない）。
対応 UI ロケールは config の `languages.ui_locales`（テンプレは `languages.ui_template_locale`）。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<画面/コンポーネント名>" [issue番号] ui`
   → `docs/issues/<issue_name>/status.json`（種別 ui）。
2. **デザイン＆実装** — `Agent(subagent_type: "ui-designer")` に対象と status.json パスを渡す。
   エージェントはデザイントークン＋既存の共有コンポーネントを**再利用**してワイヤーを起こし
   （[.claude/docs/DESIGN.md] / [.claude/rules/CODING.md] のデザインシステム準拠）、該当 feature の
   presentation 層に規約どおり配線して実装、文言は config の `ui_l10n_dir` の i18n リソースに
   `ui_locales` 全言語ぶん追加（生成物は手で編集しない）、**通常/空/ローディング/エラー**を網羅する。
3. **検証（必須スクリプト・スタック固有コマンド手打ち禁止）**:
   `bash .claude/skills/wf-verify/scripts/run-checks.sh`（config の `components[].checks` を解決して実行）で
   **RESULT: PASS** を確認。可能なら実機/エミュで見え方を確認（スクショ）。NG なら実装へ差し戻す。
4. **commit**: `UI: <画面/コンポーネント> (#NN)`（接頭辞は config.commit_prefixes の ui="UI"）。
5. 変更ファイル・使用トークン/コンポーネント・網羅状態・検証結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh ... ui` で status.json を作成
- [ ] **デザインシステムのトークンのみ使用**（ハードコード色/余白なし・[.claude/docs/DESIGN.md]/[.claude/rules/CODING.md] 準拠）
- [ ] 文言は **i18n リソースに `ui_locales` 全言語**（生成物は手で編集しない）
- [ ] 主要状態（通常/空/ローディング/エラー）を網羅
- [ ] **`run-checks.sh` が RESULT: PASS**（スタック固有コマンド手打ち禁止）
- [ ] commit: `UI: <画面/コンポーネント> (#NN)`

複雑な機能で設計→実装→検証→レビュー→MR を通したい場合は、UI 実装をこのスキルで行い、全体は wf
ワークフローのノードに組み込んでよい。
