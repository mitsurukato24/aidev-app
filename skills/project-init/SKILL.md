---
name: project-init
description: 新規プロジェクトの .claude プロジェクト固有層（PROJECT.md / config.json / docs / rules）を雛形（.claude/templates/project/）から scaffold する。フレームワーク本体（skills/agents/templates）は触らず再利用する。
---

# プロジェクト初期化ノード（project-init）

AIDD フレームワークを**別アプリで使い始める**ためのメタ Skill。フレームワーク本体
（`.claude/skills` / `agents` / `templates`）は不変のまま、**プロジェクト固有層だけ**を
`.claude/templates/project/` の雛形から生成する。全体像は [.claude/rules/WORKFLOW.md]、層の分離は
[.claude/rules/DIRECTORY.md]。

**生成対象（プロジェクト固有層のみ）**: `.claude/PROJECT.md` / `.claude/config.json` /
`.claude/docs/DESIGN.md` / `.claude/docs/SPEC.md` / `.claude/rules/{CODING,SECURITY,DATA_POLICY,DIRECTORY}.md`。
WORKFLOW.md / GIT.md / QUALITY.md は**汎用**なのでフレームワーク現物をコピーする（雛形化しない）。

1. **対象アプリの情報を集める**（対話 or 引数）。最低限:
   - 製品名（`PRODUCT_NAME`）／コードネーム（`CODENAME`）／1 行要約（`PRODUCT_SUMMARY`）。
   - スタック＝各 **component**（`name` / `path` / `stack` と、その **lint / test コマンド・cwd・coverage_gate**）。
   - 言語割当（converse / code / docs / UI ロケール）、VCS（default_branch / issue_tracker / commit 言語・trailer・footer）。
   - 配信先（deploy.targets）／鍵なし動作（runtime_verify・mock or テスト契約）／ユーザー像・予算権限。
   - ドメイン固有 Skill の要否（無ければ `domain_skills` は空 `[]`）。
   不明点は WORKFLOW の優先度判定と同じくユーザーに確認するが、可逆な既定値（例 default_branch=main）は決めて進める。
2. **雛形を実値に置換して生成**する。`.claude/templates/project/*.tmpl` を以下へ展開し、`{{...}}`
   プレースホルダを 1. の実値に置換、各テンプレ内コメント（`<!-- ... -->`）の指示に沿って
   スタック固有の中身を埋める（埋めたらコメントは削除する）:
   - `PROJECT.md.tmpl` → `.claude/PROJECT.md`
   - `config.json.tmpl` → `.claude/config.json`（`_example` キーは不要なら削除。components は
     **全 component を列挙**し、各 check の lint/test/cwd/coverage_gate を埋める）
   - `DESIGN.md.tmpl` → `.claude/docs/DESIGN.md` ／ `SPEC.md.tmpl` → `.claude/docs/SPEC.md`
   - `rules/{CODING,SECURITY,DATA_POLICY,DIRECTORY}.md.tmpl` → `.claude/rules/{CODING,SECURITY,DATA_POLICY,DIRECTORY}.md`
3. **汎用 rules をコピー**する。`WORKFLOW.md` / `GIT.md` / `QUALITY.md` はフレームワーク現物を
   `.claude/rules/` へコピーする（雛形化しない）。GIT.md のマージ前ゲートの文言や commit trailer/footer など
   プロジェクト依存の箇所が残っていれば、`config.json`（vcs / components の checks）駆動の表現に調整する
   （ハードコードしたスタック名を「config の checks」と言い換える等）。`.claude/templates/status.schema.json`
   などフレームワーク本体はそのまま再利用する。
4. **config が読めることを確認**する。`python3 .claude/skills/lib/config.py get project.codename` 等で
   値が引けること＝`config.json` が妥当な JSON であることを検証する（`config.py checks` / `components` も確認）。
5. **eval が PASS することを確認**する。`bash .claude/skills/run-evals.sh` を回し、本 Skill を含め
   全 Skill の eval が PASS することを確認してから完了とする（実行は利用者＝この手順を回す人が行う）。

## 必須チェックリスト（省略不可）
- [ ] 雛形（`.claude/templates/project/`）から**全プロジェクト固有層を生成**（PROJECT.md / config.json /
      docs/DESIGN.md / docs/SPEC.md / rules/{CODING,SECURITY,DATA_POLICY,DIRECTORY}.md）し、`{{...}}` の未置換を残さない
- [ ] `config.json` が**有効な JSON** で、`python3 .claude/skills/lib/config.py get project.codename` 等で読める
- [ ] components に**全 component を列挙**し、各 check の lint/test/cwd/coverage_gate を埋めた
- [ ] `domain_skills` は新規では**空 `[]`**（必要なドメイン Skill があるときのみ列挙）
- [ ] 汎用 rules（WORKFLOW / GIT / QUALITY）は現物をコピー（必要なら config 駆動表現に調整）
- [ ] **フレームワーク本体（`.claude/skills` / `agents` / `templates`）は触らない**（再利用するだけ）
- [ ] `bash .claude/skills/run-evals.sh` が **PASS**
