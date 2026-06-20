---
name: api-design
description: APIデザイン — API エンドポイント/契約・リクエスト/レスポンス DTO の設計実装を wf-implementer サブエージェントで行い、検証して commit する。引数 = 対象エンドポイント/契約（例「ユーザー進捗取得 API」+ issue番号 任意）。層責務・契約ドリフト・鍵漏れを必ずチェック。
---

# APIデザイン

API のエンドポイント/契約・DTO を設計実装する、実装ノードの専用バリアント。駆動エージェントは
`wf-implementer`。全体像は [.claude/rules/WORKFLOW.md]。スタック固有のコマンド/フレームワークは
直書きせず、**このプロジェクトの規約（[.claude/rules/CODING.md] と [.claude/docs/DESIGN.md]）に従う**
（言語/層構成は config 駆動）。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<エンドポイント/契約名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **設計＆実装** — `Agent(subagent_type: "wf-implementer")` に対象と status.json パスを渡す。
   エージェントは**境界の層責務を守って**（router は薄く＝検証して service に委譲、ロジックを境界の外に
   出さない）リクエスト/レスポンス DTO を型付きで定義し、クライアントとサーバの契約をそろえて実装、
   mock とテストを追加する。規約は [.claude/rules/CODING.md] / [.claude/docs/DESIGN.md]。
3. **検証（必須スクリプト・スタック固有コマンド手打ち禁止）**:
   `bash .claude/skills/wf-verify/scripts/run-checks.sh`（config の checks を解決して実行）で
   **RESULT: PASS** を確認。NG なら実装へ差し戻す。
4. **commit**: `実装: <エンドポイント/契約名> (#NN)`（接頭辞は config.commit_prefixes の implement="実装"）。
5. 変更ファイル・契約（DTO の型）・互換性・検証結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **層責務**を守る（router 薄→service にロジック委譲。ロジックを境界の外に出さない＝CODING 準拠）
- [ ] リクエスト/レスポンス **DTO を型付き**で定義（API 契約を明示）
- [ ] **後方互換 or 契約テスト**を用意し、**クライアント⊆サーバの契約ドリフト**を検知できる
- [ ] **鍵/トークンをクライアントに渡さない**（[.claude/rules/SECURITY.md]）
- [ ] mock・テストを追加（鍵なしで決定的に通る）
- [ ] **`run-checks.sh` が RESULT: PASS**（スタック固有コマンド手打ち禁止）
- [ ] commit: `実装: <エンドポイント/契約名> (#NN)`

複雑な場合は wf ワークフローのノードとして組み込んでよい。
