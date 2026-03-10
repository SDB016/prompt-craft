# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | [한국어](README.ko.md) | **日本語** | [中文](README.zh.md)

**Claude Code向けプロンプトレビュー。コードレビューは結果を見る — プロンプトレビューは原因を見る。**

---

## クイックスタート

**ステップ1: インストール**
```
/plugin marketplace add https://github.com/SDB016/prompt-craft
/plugin install prompt-craft
```

**ステップ2: セットアップ（インストール直後に実行）**
```
/setup           # レビューリポジトリを確認 → すべて自動設定
```

**ステップ3: プロンプトレビュー**
```
/review          # プロンプトレビューPR作成
/score           # ローカルスコアリング（PR作成なし）
```

プロンプトは`git push`のたびに**自動キャプチャ**されます。
`/review`がキャプチャされたプロンプトを集約し、スコアリング付きPRをレビューリポジトリに作成します。

> **注意:** 初回インストール後、push hookを有効にするにはClaude Codeを再起動してください。`/setup`をスキップすると、セッション開始時に通知が表示されます。

---

## なぜPrompt Craftなのか？

- **チームレベルのプロンプト品質** - GitHub PRを通じてAIプロンプトを相互レビュー
- **自動スコアリング** - 8基準、100点満点、単一LLM呼び出し
- **プロジェクト無痕跡** - すべてのレビューPRは別リポジトリへ、プロジェクトに痕跡なし
- **コードレビューの補完** - コードは証拠、プロンプトは原因
- **セキュリティファースト** - 送信前プレビュー、自動シークレットスキャン

---

## スキル

| スキル | 用途 |
|--------|------|
| `/review` | チームフィードバック用プロンプトレビューPR作成 |
| `/score` | ローカルスコアリング + 改善ヒント (`--verbose`) |
| `/insights` | スコアトレンド、高スコアパターン、セッション比較 |
| `/prompt-guide` | タスク前プロンプトガイド + 再利用テンプレート |
| `/setup-project` | プロジェクト別キャプチャ設定（有効化、無効化、カスタムリポジトリ） |

### review

| コマンド | 動作 |
|----------|------|
| `/review` | プロンプトレビューPR作成 |
| `/review --push` | Hookトリガーpushキャプチャ |
| `/review --status` | 設定 + 最近のPR表示 |
| `/review --doctor` | 前提条件チェック (git, gh, jq) |
| `/review --setup` | 設定再構成 |

### insights

| コマンド | 動作 |
|----------|------|
| `/insights` | 時系列スコアトレンド |
| `/insights --team` | 全著者のトレンド |
| `/insights patterns` | 高スコアプロンプトパターン抽出 |
| `/insights compare #1 #2` | 2つのレビューセッション比較 |

### prompt-guide

| コマンド | 動作 |
|----------|------|
| `/prompt-guide` | コンテキストベースのプロンプト作成ヒント |
| `/prompt-guide template save/list/use/delete` | 再利用テンプレート管理 |

### setup-project

| コマンド | 動作 |
|----------|------|
| `/setup-project` | 現在のプロジェクトキャプチャ状態を表示 |
| `/setup-project on` | 現在のプロジェクトのキャプチャを有効化 |
| `/setup-project on --repo R` | 特定のレビューリポジトリでキャプチャを有効化 |
| `/setup-project off` | キャプチャを無効化（自動スキップ） |
| `/setup-project list` | 全プロジェクト設定を表示 |
| `/setup-project reset` | スキップしたプロジェクトの再質問を有効化 |

### 自動フロー

| イベント | 動作 | プロンプトリポジトリ |
|----------|------|----------------------|
| `git push`（Claude Code内） | プロンプト + diff キャプチャ | **コミットのみ**（PRなし） |
| `gh pr create`（Claude Code内） | 集計 + スコアリング | **PR作成** |
| `/review`（手動） | 任意のタイミングでPR作成 | **PR作成** |

---

## 仕組み

```
[開発中 — 各pushで記録]

  Claude Codeで作業
        │
        ├── git push #1 → プロンプトリポジトリにコミット（プロンプト + diff記録）
        ├── git push #2 → プロンプトリポジトリにコミット（追加記録）
        ├── git push #3 → プロンプトリポジトリにコミット（追加記録）
        │
[機能完了 — PR時にスコアリング]
        │
        └── gh pr create（コードリポジトリにPR）
              │
              ▼
    蓄積されたプロンプト集計 + AIスコアリング（100点）
              │
              ▼
    プロンプトリポジトリにPR作成
              │
              ▼
    チームメンバーがプロンプト品質をレビュー
```

プロジェクトリポジトリに痕跡を残しません。すべてのレビューPRは別リポジトリ（例: `my-org/ai-sessions`）に作成されます。

---

## スコアリングシステム

8基準、100点満点。単一LLM呼び出しで評価。

| 基準 | 配点 | 説明 |
|------|------|------|
| 目標明確性 (Goal Clarity) | 20 | 目標が具体的で、結果が意図と一致しているか？ |
| 範囲制御 (Scope Control) | 15 | 境界が設定され、制約が明示され、範囲外の変更がないか？ |
| コンテキスト充足性 (Context Sufficiency) | 15 | 十分な背景（参照コード/パターン含む）が提供されているか？ |
| 終了基準 (Exit Criteria) | 10 | 完了/停止条件が明示され、遵守されているか？ |
| 分解 (Decomposition) | 10 | 複雑なタスクが適切に分割されているか？ |
| 検証戦略 (Verification Strategy) | 10 | 検証方法が明示されているか？ |
| 反復品質 (Iteration Quality) | 10 | フォローアップリクエストが具体的で明確か？ |
| 複雑度適合 (Complexity Fit) | 10 | プロンプトの精緻さがタスクの複雑さに適しているか？ |

### ギャップモデル

| ギャップ | 説明 | 評価者 |
|----------|------|--------|
| Gap 1 | 意図 → プロンプト | 人間のみ |
| Gap 2 | プロンプト → コード | AI補助可能 |

---

## PR例

```markdown
## Score: 73/100 — JWTリフレッシュロジックのリファクタリング

> Prompts: 6 | Duration: ~35 min | LLM scored

## Prompt Quality Scorecard

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| ✅ | Goal Clarity | 18/20 | █████████░ | 明確な目標指定 |
| ❌ | Exit Criteria | 4/10 | ████░░░░░░ | 停止条件なし |
| ...

## What Was Produced
> 5 files changed, +142 −38

## Improvement Suggestions
### Exit Criteria (4/10)
> Claudeが範囲を超過。Prompt Gap: 終了基準未指定。
```

---

## トラブルシューティング

| 問題 | 解決 |
|------|------|
| インストール後Hookが動作しない | Claude Codeセッションを再起動してプラグインhookを再読み込み |
| 設定エラー | `~/.claude/prompt-review.config.json`を削除して`/setup`を実行し再設定 |

---

## 要件

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/)（PR作成用）
- Git

---

## ライセンス

MIT — [LICENSE](LICENSE)を参照
