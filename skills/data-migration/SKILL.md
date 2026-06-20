---
name: data-migration
description: データマイグレーション — DB スキーマ/モデル変更＋マイグレーションを wf-implementer サブエージェントで実装し、検証して commit する。引数 = 対象の変更（例「進捗テーブルに streak 列追加」+ issue番号 任意）。**マイグレーション登録漏れ防止**が最重要（登録漏れは本番だけ落ちる＝CI は緑のまま通る既知の落とし穴）。
---

# データマイグレーション

DB スキーマ/モデル変更とマイグレーションを行う、実装ノードの専用バリアント。駆動エージェントは
`wf-implementer`。全体像は [.claude/rules/WORKFLOW.md]。スタック固有の ORM/マイグレーション機構は
直書きせず、**このプロジェクトの規約（[.claude/rules/CODING.md] と [.claude/docs/DESIGN.md]）に従う**
（DB 方言/マイグレーション登録の仕組みは config 駆動）。

> **最重要・既知の落とし穴**: モデルに**列を追加したらマイグレーション登録を必ず行う**こと。
> 登録漏れはローカル（新規作成 DB）と CI（テスト用 DB）では再現せず緑のまま通り、**本番（既存 DB）
> だけが起動/クエリ時に落ちる**。実装の最後に「モデルの変更 ↔ マイグレーション登録」が 1:1 で
> そろっているかを必ず突き合わせる。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<スキーマ変更名>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **設計＆実装** — `Agent(subagent_type: "wf-implementer")` に対象と status.json パスを渡す。
   エージェントはモデル変更と**対応するマイグレーション登録**をセットで行い、**冪等なロード**（再実行で
   壊れない）にし、テストを追加する。規約は [.claude/rules/CODING.md] / [.claude/docs/DESIGN.md]。
3. **検証（必須スクリプト・スタック固有コマンド手打ち禁止）**:
   `bash .claude/skills/wf-verify/scripts/run-checks.sh` で **RESULT: PASS** を確認。NG なら実装へ
   差し戻す。
4. **commit**: `実装: <スキーマ変更名> (#NN)`（接頭辞は config.commit_prefixes の implement="実装"）。
5. 変更ファイル・追加列/制約・マイグレーション登録の有無・ロールバック方針・検証結果を日本語で報告。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **モデル列追加時にマイグレーション登録を必ず行う**（登録漏れは本番だけ落ちる＝CI は緑のまま通る）
- [ ] **冪等なロード**（マイグレーション/シード投入を再実行しても壊れない）
- [ ] **ローカルと本番で DB 方言が違う場合は両対応**（片方だけで通る変更を避ける）
- [ ] **ロールバック方針**を明記
- [ ] テストを追加（鍵なしで決定的に通る）
- [ ] **`run-checks.sh` が RESULT: PASS**（スタック固有コマンド手打ち禁止）
- [ ] commit: `実装: <スキーマ変更名> (#NN)`

複雑な場合は wf ワークフローのノードとして組み込んでよい。
