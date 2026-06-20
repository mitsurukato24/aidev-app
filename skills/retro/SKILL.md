---
name: retro
description: レトロスペクティブ＋Skill自己改善 — 過去の作業台帳(status.json)・メトリクス(トークン/速度/手戻り)・PRレビュー指摘を QUALITY.md の6観点で分析し、「指摘や手戻りを受けないにはどうすべきだったか」を反省して Skill/rule を改善する。改善は修正前後のブラインドA/B比較で検証し、勝ったものだけ採用して eval で固定する。採点は上限なし加点・前回比の相対評価。
---

# retro — レトロスペクティブと Skill 自己改善

開発フローを「使うほど良くなる」ようにするメタ Skill。ルール: [.claude/rules/QUALITY.md]（6観点・相対採点・
ブラインドA/B）/ 全体像 [.claude/rules/WORKFLOW.md] §6。**バイアス排除**のため、改善の良し悪しは自分で
判断せず、修正前後の成果物を**伏せて**別 agent に比較させる。

## 手順

1. **収集（retrospector）** — `Agent(subagent_type: "retrospector")` に対象範囲（直近N件 / 期間 / Issue群）を
   渡す。エージェントは以下を読む:
   - 完了タスクの台帳 `<work_ledger_dir>/<issue_name>/status.json`（`paths.work_ledger_dir`）＝各ノードの
     結果・findings・**metrics**（tokens/duration/loopbacks/artifacts）。
   - 当該ブランチの git 履歴（「レビュー対応」commit・マージ後の同 issue 修正＝手戻りの痕跡）。
   - PR のレビュー指摘（`gh pr view <PR> --comments` / review threads）。
   - 前回の `docs/retro/scoreboard.json`（`paths.retro_dir`）＝相対評価の基準値・累積ポイント。

2. **6観点で採点（前回比・上限なし加点）** — QUALITY.md の ①手戻り ②速度 ③網羅性/検証 ④トークン
   ⑤成果物品質 ⑥抜け漏れ。tokens/duration は**タスク規模で正規化**してから前回（基準値/移動平均）と比較し、
   観点ごとに `前回比 +X/−Y` と Δポイントを出す（絶対100点満点にしない＝飽和させない）。②速度 と ③網羅性の
   **バランス**も評価する。

3. **根本原因と改善案（retrospector）** — 繰り返し出た指摘・手戻り・遅延・過大トークンを症状でなく根本原因
   まで掘り、「どうすべきだったか」を、**具体的な Skill/rule への変更案（diff の要点）**に落とす
   （対象: `SKILL.md` / `.claude/agents/*` / `.claude/rules/*` / `.claude/config.json`）。

4. **ブラインド A/B 検証（最重要・バイアス排除）** — 改善を採用する前に必ず対戦させる:
   1. 改善案を**修正後 Skill** として用意（修正前は git で復元可能）。
   2. 代表タスクを **修正前 / 修正後** の双方で実施し、2つの成果物を得る（同一タスク・同一入力）。
   3. このメインループ（オーケストレータ）が 2 成果物を **匿名化（成果物A / 成果物B）・順序をランダム化**し、
      **どちらが修正後かを伏せて** `Agent(subagent_type: "eval-judge")` に渡す。A/B↔前後の**対応表は判定後まで
      eval-judge に渡さない**（封印）。乱数/封印はメインループが担う（スクリプトの乱数制約回避）。
   4. eval-judge は6観点で**ペア比較**し、勝者と差分を返す。
   5. **修正後が勝ったときだけ採用**（負け/引き分けは破棄 or 再設計）。

5. **採用 → eval で固定** — 採用改善を適用し、**`bash .claude/skills/run-evals.sh`** が PASS することを確認、
   対応する `<skill>/eval/spec.json` の `must_contain` に**新しい不変項**を追加（同じ指摘の再発を機械検出で固定）。

6. **出力** — `.claude/templates/retro-report.md` で `docs/retro/<date>-<scope>.md` を生成（観点別 前回比＋
   累積＋根本原因＋A/B結果＋採用改善）。`docs/retro/scoreboard.json` を今回値で更新。各改善は論理単位で commit。

## 必須チェックリスト（省略不可）
- [ ] 台帳・metrics・git履歴・PRレビュー指摘を収集し6観点で採点（**前回比・上限なし加点**。絶対満点にしない）
- [ ] 根本原因→具体的な Skill/rule 改善案に落とした（症状でなく原因）
- [ ] 改善は **修正前後のブラインドA/B**（どちらが修正後か非開示）で検証し、**勝ったものだけ採用**
- [ ] 採用後 **`run-evals.sh` PASS** ＋ 対応 eval spec の `must_contain` に不変項追加（再発固定）
- [ ] `retro-report.md` 出力＋`scoreboard.json` 更新＋論理単位で commit

## 原則
- 評価の独立性を最優先（修正者＝評価者にしない）。判定前に修正前後を明かさない。
- 改善はフレームワーク本体（`.claude/skills|agents|templates`）と rules に対して行い、特定プロジェクト固有の
  事情は config/PROJECT 側に寄せる（汎用性を壊さない）。
