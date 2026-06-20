<!--
retro Skill の出力雛形（docs/retro/<date>-<scope>.md として書き出す。retro_dir は config.paths.retro_dir）。
採点は QUALITY.md に従う＝上限なし加点・前回比の相対評価。改善は修正前後のブラインドA/B比較で検証してから採用。
基準値・累積ポイントは docs/retro/scoreboard.json に保持（retrospector が読み書き）。
-->

# レトロスペクティブ: <対象範囲（例: 直近10タスク / Issue #NN / 期間 YYYY-MM-DD〜）>

| 項目 | 値 |
|---|---|
| 実施日 | <YYYY-MM-DD> |
| 対象タスク | <issue_name 一覧 or 件数> |
| 前回 retro | <docs/retro/<前回>.md> |

## 1. 6観点スコア（前回比・上限なし加点）

各観点は QUALITY.md の定義。`今回値` は metrics/台帳/PRレビューから集計、`前回比` は scoreboard.json の
基準値（直近/移動平均）との差。規模補正後（tokens/duration はタスク規模で正規化）。

| # | 観点 | 今回値（集計） | 前回比 | Δポイント | 累積 |
|---|---|---|---|---|---|
| 1 | 手戻り rework | <verify FAIL n / review高 n / 手戻り loopbacks n> | <改善/悪化> | <+/−> | <累積> |
| 2 | 速度 speed | <duration 規模補正> | | <+/−> | |
| 3 | 網羅性・検証 coverage | <cov% / テスト追加 / 状態網羅> | | <+/−> | |
| 4 | トークン tokens | <total 規模補正・best-effort> | | <+/−> | |
| 5 | 成果物クオリティ quality | <findings重大度 / マージ後不具合> | | <+/−> | |
| 6 | 抜け漏れ completeness | <未チェック項目 / 受入未達 / docs漏れ> | | <+/−> | |
| | **合計Δ** | | | <**+/−**> | <**累積**> |

> ②速度 と ③網羅性 のバランス所見: <速いが薄い／厚いが冗長／良好 など>

## 2. 根本原因（指摘・手戻りを受けないにはどうすべきだったか）

タスク横断で**繰り返し**出た指摘・手戻り・遅延・過大トークンを、症状でなく**根本原因**まで掘る。

| 観測された問題（再発） | 根本原因 | どうすべきだったか | 影響したSkill/rule |
|---|---|---|---|
| <例: review高で層責務違反が頻発> | <SKILL.md に層チェックが弱い> | <implementer の必須チェックに層責務を追加> | wf-implement / CODING.md |

## 3. 改善案 → ブラインドA/B検証 → 採用判定

| 改善案（diff の要点） | 対象ファイル | A/B検証の代表タスク | eval-judge 判定（勝者・差分） | 採用 |
|---|---|---|---|---|
| <例: implementer に層責務チェック追加> | .claude/agents/wf-implementer.md | <Issue #NN を修正前/後で実施> | <修正後 勝ち: 手戻り−2/網羅+1> | ✅ |
| <負け/引き分けは破棄 or 再設計> | | | <修正前 勝ち> | ❌破棄 |

- 採用した改善は **`run-evals.sh` 再実行で PASS** を確認し、対応する `eval/spec.json` の `must_contain` に
  新不変項を追加（再発の機械検出で固定）。
- ブラインド手順: 成果物を匿名化(A/B)・順序ランダム化し、どちらが修正後かを伏せて `eval-judge` に渡す
  （対応表は判定後まで非開示）。詳細は QUALITY.md / retro SKILL.md。

## 4. 次アクション
- [ ] <採用改善の適用commit（Skill/rule）>
- [ ] <eval spec 更新commit>
- [ ] <scoreboard.json 更新（今回値を基準へ反映）>
