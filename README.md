# aidev-app — AIDD (AI-Driven Development) framework

任意のアプリ開発に使える、再利用可能な **AI駆動開発フレームワーク**本体。プロジェクト固有の値は一切
含まず（汎用フレームワークのみ）、各プロジェクトの `.claude/` に **git subtree** で取り込んで使う。

## 中身（= 取り込み先の `.claude/` にマッピング）

```
skills/      # 汎用Skill: フロー(wf, wf-design…wf-mr) / メタ(retro, project-init) /
             #   アプリ開発専用(ui-design, api-design, data-migration, i18n, runtime-verify,
             #   deploy, release, debug, refactor, ci) / lib(config.py) / eval_runner.py
agents/      # 汎用sub-agent: wf-* / retrospector / eval-judge / deployer / runtime-verifier / ui-designer
templates/   # status.schema.json / design-doc / retro-report / 画面ドキュメント / UIデザイン台帳 / project(雛形)
rules/       # 汎用ルール: WORKFLOW.md / GIT.md / QUALITY.md
```

**含まないもの（＝各プロジェクト側でローカルに持つ）**: `PROJECT.md` / `config.json` / `docs/{DESIGN,SPEC}.md` /
`rules/{CODING,SECURITY,DATA_POLICY,DIRECTORY}.md` / ドメイン固有Skill（例: 学習コンテンツ著作 `content-gen`）。
これらの雛形は `templates/project/` にあり、`project-init` Skill が生成する。ルート `CLAUDE.md` の雛形は
`templates/project/CLAUDE.md.tmpl`。

## 消費プロジェクトでの使い方（subtree）

初回取り込み（`.claude` を subtree 化。汎用部分が入る。プロジェクト固有は別途ローカルに置く）:

```bash
git rm -r .claude && git commit -m "chore: drop .claude (subtree化の前段)"
git subtree add --prefix=.claude <aidev-app の remote または ../aidev-app> main --squash
# その後 PROJECT.md / config.json / docs / rules(CODING等) / ドメインSkill をローカルに追加コミット
```

フレームワーク更新の取り込み（プロジェクト固有のローカルファイルは保持される）:

```bash
git subtree pull --prefix=.claude <remote> main --squash
```

フレームワークへの改善の逆流（このリポへ push back）:

```bash
git subtree push --prefix=.claude <remote> <branch>
```

## 設計思想
開発フロー・やるべきこと・テストは「どんなアプリでも不変」。変わる言語/基盤/配信先は `.claude/config.json`
（機械可読）と `.claude/rules/` の各プロジェクト側で吸収する。スクリプトは config を読んでスタック非依存に
動く（`run-checks.sh` は `components[].checks` を実行）。詳細は `rules/WORKFLOW.md` / `rules/QUALITY.md`。
