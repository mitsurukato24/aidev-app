# GIT ルール — バージョン管理の決まり

## コミット単位とブランチ

- **コミットは各作業ごとに行う**（明示依頼を待たない）。ワークフローの各ノード（設計／実装／検証／
  レビュー対応）や、コンテンツ著作・UI 実装などの 1 単位が終わるたびにコミットする。作業の区切りで
  小さく積む＝レビューと巻き戻しを容易にする。
- **push は外向き操作のため明示依頼時のみ**（取り消し困難）。ローカルコミットは自走、push/PR は確認。
- **作業は Issue ごとの worktree＋ブランチで行う**（[WORKFLOW.md]）。`new-worktree.sh` が
  `.worktree/<issue_name>/` に専用 worktree とブランチ `<issue_name>` を作り、**各ノードのコミットは
  そのブランチに積む**（`main` へ直接コミットしない）。`main` への反映は MR ノードの PR マージで行う。
  1 Issue = 1 worktree = 1 ブランチで並行作業を隔離し、同名ブランチの一意性が二重作業の hard lock になる。
- 既定の PR 先（base）は `main`。**`main` へマージするか否かは PM が判断する**（[WORKFLOW.md] のマージ判断
  ノード）。PR マージ後は `finish-worktree.sh` で worktree を撤去する。

## コミットメッセージ

- **日本語**で書く（既存履歴に合わせる）。
- 関連する GitHub Issue は `#NN`、要件 ID は `R-NN`（または `SPEC §x`）を本文に含めてトレーサビリティを確保する。
  - 例: `#35 GraphRAG取り込み＋年次1→目標ロードマップ組成 (R-27/R-34)`
- 1 コミット = 1 つの意味のある単位。生成物（`coverage/`, `.dart_tool/`, `*.db` 等）は含めない（`.gitignore` 済み）。
- 末尾に必ず以下の trailer を付ける:

  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  ```

## プルリクエスト

- 操作は `gh` CLI を使う（認証済み）。本文は日本語。
- 何を・なぜ変えたか、関連 Issue（`Closes #NN`）、検証結果（pytest / flutter test の通過）を記載する。
- PR 本文の末尾に付ける:

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

## 機密・安全

- `.env` や鍵・トークンを**絶対にコミットしない**（詳細は [SECURITY.md]）。
- 外向き操作（push, PR 作成, Issue 作成・クローズ）は、外部公開＝取り消し困難であることを踏まえ、依頼または明確な合意のもとで行う。

## マージ前ゲート（マージ判断＝PM の専管）

- **`main` へのマージは PM が判断・実行する**（sub エージェントに委譲しない）。MR ノードは PR 作成までを担い、
  取り込むか否かは PM が決める。判断は PM が自走して下す（ユーザー可否は仰がない。予算超過の恐れがある場合のみ例外）。
- マージ前ゲート（すべて満たして初めて `gh pr merge`）:
  - CI（backend pytest ≥90% / Flutter analyze + test ≥90%）が緑であること（`gh pr checks` で確認）。ローカルでも push 前に両方を通す（[CODING.md] 参照）。
  - レビューの重大度・高の指摘が未解消で残っていないこと。
  - 各ノードのコミットが積まれ、作業ツリーがクリーンであること。
- ゲートを満たさなければマージせず実装ノードへ差し戻す。マージ後は `finish-worktree.sh` で後片付けする。
