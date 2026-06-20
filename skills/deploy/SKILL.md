---
name: deploy
description: デプロイ — config.deploy.targets の宣言的レシピに従いサーバ/CDN/Hosting（container/object-storage/static-hosting）へ冪等に配信し、配信後スモークを行う専用 Skill。駆動エージェントは deployer。外向き操作＝取り消し困難なので秘密を出さず慎重に。引数 = 対象 target 名（例「backend」「content」+ issue番号 任意）。
---

# デプロイ（deploy）

`config.deploy.targets` の**宣言的レシピ**に従い、対象（サーバ/CDN/Hosting）へ配信する専用ノード。
駆動エージェントは `deployer`。全体像は [.claude/rules/WORKFLOW.md]。配信先・コマンド・`kind`
（container / object-storage / static-hosting）はすべて **`.claude/config.json` 由来**（ホスト/スタックを
直書きしない）。**外向き操作＝取り消し困難**なので [.claude/rules/SECURITY.md] と予算方針に従い慎重に。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<target名 デプロイ>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **配信** — `Agent(subagent_type: "deployer")` に対象 target 名と status.json パスを渡す。エージェントは
   `config.deploy.targets[]`（`kind` / `describe` / `cmd`）の該当レシピに従い**冪等**に配信する（再実行で
   壊れない・既存版は no-op ゲートでスキップ）。秘密情報は環境変数 / CI シークレット経由のみ。
3. **配信後スモーク**: 健全性エンドポイント／公開アセット取得などで配信結果を確認し、コマンドと出力を
   「3. 検証」節へ証跡として記録する。**予算超過の恐れがあれば配信せず PM へ**エスカレーション。
4. **commit**: `デプロイ: <target名> (#NN)`（接頭辞は config.commit_prefixes の deploy="デプロイ"）。
5. 配信 target・実行コマンド・スモーク結果・予算メモを日本語で報告。**本番反映の最終判断は PM**。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] 対象 **target のレシピに従う**（`config.deploy.targets` の `kind`/`cmd`・直書きしない）
- [ ] **秘密情報をコミットしない**（環境変数 / CI シークレット経由・diff に `.env`/鍵なし）
- [ ] **冪等**（再実行で壊れない・既存版は no-op ゲート）
- [ ] **配信後スモーク**を実施し証跡を記録（健全性／公開アセット確認）
- [ ] **予算超過の恐れは配信せず PM へ**／本番反映の最終判断は PM
- [ ] commit: `デプロイ: <target名> (#NN)`

複雑な場合は wf ワークフローのノードに組み込んでよい。
