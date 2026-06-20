<!--
UI デザインの専用セクション（Skill: ui-design / agent: ui-designer）。
ui-design Skill / ui-designer agent が参照するデザインガイド（status.json は状態のみを持つ）。
ルール: docs/設計書.md §8（色/タイポ/余白/コンポーネント）, .claude/rules/CODING.md（Flutter 規約・l10n）。
実装前のデザイン合意と、実装後の見え方確認をこのセクションで管理する。
検証: bash .claude/skills/wf-verify/scripts/run-checks.sh
-->

# UIデザイン台帳: <画面 / コンポーネント名>

| 項目 | 値 |
|---|---|
| 対象 | <feature/画面>（例 features/plan/today_screen） |

### 要件・狙い

- **ユーザー価値 / 目的**: <この UI で何を達成するか>
- **対象状態**: 通常 / 空 / ローディング / エラー / 課金ロック 等 <該当を列挙>

### デザイン方針（設計書 §8 準拠）

- **トークン**: 色 / タイポ / 余白を `docs/設計書.md` §8 のトークンから選ぶ（独自値を散らさない）
- **レイアウト（ワイヤー）**:
  ```
  <ASCII ワイヤーフレーム>
  ```
- **既存コンポーネント再利用**: `shared/widgets/`（AppCard, buttons, reward 等）から再利用、不足分のみ新設
- **モーション / 演出**: `core/anim`（juice）整合。やり過ぎない
- **i18n**: 文言は `lib/l10n/*.arb` に追加（直書き禁止）。5 言語ぶんのキーを用意

### 実装・確認チェック（必須）

- [ ] 設計書 §8 のデザイントークンのみ使用（ハードコード色/余白なし）
- [ ] 文言は ARB 経由（`en/ja/zh/de/ko`）
- [ ] 主要状態（空/ローディング/エラー）を実装
- [ ] **`bash .claude/skills/wf-verify/scripts/run-checks.sh` が RESULT: PASS**（flutter analyze + test・手打ち禁止）
- [ ] 実機 or エミュで動作確認（スクショ）

**完了したら commit:** `UI: <画面/コンポーネント> (#NN)`
