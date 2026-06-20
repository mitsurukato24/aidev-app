---
name: release
description: リリース — クライアント配信（署名・ストア/Play 配布・版採番）を config.deploy.targets(app-store) のレシピに従って行う専用 Skill。駆動エージェントは deployer。ビルド番号は単調増加（同番拒否回避）・署名構成・リリースノート・秘密を出さない。引数 = リリース対象（例「android internal」+ issue番号 任意）。
---

# リリース（release）

クライアント（ストア配布）を出す専用ノード。署名・版採番・配布までを `config.deploy.targets` の
`app-store` レシピに従って行う。駆動エージェントは `deployer`。全体像は [.claude/rules/WORKFLOW.md]。
配布先・コマンド・署名構成は **`.claude/config.json` 由来**（プラットフォームを直書きしない）。
**外向き＝取り消し困難**なので [.claude/rules/SECURITY.md] と予算方針に従い慎重に。

1. **作業フォルダ作成（必須スクリプト）**:
   `bash .claude/skills/wf/scripts/new-status.sh "<リリース対象>" [issue番号]`
   → `docs/issues/<issue_name>/status.json`。
2. **ビルド＆配布** — `Agent(subagent_type: "deployer")` に対象と status.json パスを渡す。エージェントは
   `config.deploy.targets[]`（`kind: app-store`）の `describe`/`cmd` に従い、**ビルド番号を単調増加**で
   採番（同番はストアが拒否）し、**署名構成**（App Signing / 署名鍵）で署名してストア/Play へ配布する。
   鍵・トークンは環境変数 / CI シークレット経由のみ。
3. **リリースノート＆配信後確認**: リリースノートを用意し、配布結果（版が出ているか）を「3. 検証」節へ
   証跡として記録する。**予算超過の恐れがあれば配布せず PM へ**。
4. **commit**: `リリース: <リリース対象> (#NN)`（接頭辞は config.commit_prefixes の release="リリース"）。
5. 採番した版・署名構成・リリースノート・配信後確認を日本語で報告。**本番反映の最終判断は PM**。

各ノードの開始/完了で `python3 .claude/skills/wf/scripts/status.py metric <status.json> <node>
--start|--end`（差し戻し時 `--loopback`、commit 時 `--artifacts <変更ファイル数>`、tokens は best-effort）
を回す。

## 必須チェックリスト（省略不可）
- [ ] `new-status.sh` で status.json を作成
- [ ] **ビルド番号は単調増加**（同番拒否回避・既存版より大きく採番）
- [ ] **署名構成**で署名（App Signing / 署名鍵・config 由来）
- [ ] **リリースノート**を用意
- [ ] **秘密を出さない**（鍵/トークンは環境変数 / CI シークレット経由・diff に含めない）
- [ ] **予算超過の恐れは配布せず PM へ**／本番反映の最終判断は PM
- [ ] commit: `リリース: <リリース対象> (#NN)`

複雑な場合は wf ワークフローのノードに組み込んでよい。
