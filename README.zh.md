# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **中文**

**Claude Code 的提示词审查。代码审查看结果 — 提示词审查看原因。**

---

## 快速开始

**步骤1: 安装**
```
/plugin marketplace add https://github.com/SDB016/prompt-craft
/plugin install prompt-craft
```

**步骤2: 设置（安装后立即执行）**
```
/setup           # 询问审查仓库 → 自动完成所有配置
```

**步骤3: 使用**
```
git push         # 提示词自动捕获
/review          # 创建提示词审查 PR
/score           # 本地评分（不创建 PR）
```

`/setup` 会询问你的审查仓库并自动配置其余一切。之后，每次 `git push` 都会自动捕获提示词，`gh pr create` 时进行评分。

> **注意：** 首次安装后需重启 Claude Code 以激活 push hook。如果跳过 `/setup`，每次会话开始时会显示提醒。

---

## 为什么选择 Prompt Craft？

- **团队级提示词质量** - 通过 GitHub PR 互相审查 AI 提示词
- **自动评分** - 8项标准，100分满分，单次 LLM 调用
- **零项目痕迹** - 所有审查 PR 存入独立仓库，项目中无痕迹
- **代码审查的补充** - 代码是证据，提示词是原因
- **安全优先** - 发送前预览，自动密钥扫描

---

## 技能

| 技能 | 用途 |
|------|------|
| `/review` | 创建提示词审查 PR 供团队反馈 |
| `/score` | 本地评分 + 改进建议 (`--verbose`) |
| `/insights` | 分数趋势、高分模式、会话比较 |
| `/prompt-guide` | 任务前提示词指南 + 可复用模板 |
| `/setup-project` | 项目级捕获设置（启用、禁用、自定义仓库） |

### review

| 命令 | 动作 |
|------|------|
| `/review` | 创建提示词审查 PR |
| `/review --push` | Hook 触发的 push 捕获 |
| `/review --status` | 显示配置 + 最近的 PR |
| `/review --doctor` | 检查前置条件 (git, gh, jq) |
| `/review --setup` | 重新配置设置 |

### insights

| 命令 | 动作 |
|------|------|
| `/insights` | 时间维度的分数趋势 |
| `/insights --team` | 所有作者的趋势 |
| `/insights patterns` | 提取高分提示词模式 |
| `/insights compare #1 #2` | 比较两个审查会话 |

### prompt-guide

| 命令 | 动作 |
|------|------|
| `/prompt-guide` | 基于上下文的提示词编写建议 |
| `/prompt-guide template save/list/use/delete` | 管理可复用模板 |

### setup-project

| 命令 | 动作 |
|------|------|
| `/setup-project` | 显示当前项目捕获状态 |
| `/setup-project on` | 启用当前项目的捕获 |
| `/setup-project on --repo R` | 使用特定审查仓库启用捕获 |
| `/setup-project off` | 禁用捕获（自动跳过） |
| `/setup-project list` | 显示所有项目设置 |
| `/setup-project reset` | 重新启用对已跳过项目的询问 |

### 自动流程

| 事件 | 动作 | 提示词仓库 |
|------|------|-----------|
| `git push`（Claude Code 内） | 捕获提示词 + diff | **仅提交**（无 PR） |
| `gh pr create`（Claude Code 内） | 汇总 + 评分 | **创建 PR** |
| `/review`（手动） | 在需要时创建 PR | **创建 PR** |

---

## 工作原理

```
[开发中 — 每次 push 时记录]

  使用 Claude Code 工作
        │
        ├── git push #1 → 提交到提示词仓库（记录提示词 + diff）
        ├── git push #2 → 提交到提示词仓库（追加记录）
        ├── git push #3 → 提交到提示词仓库（追加记录）
        │
[功能完成 — PR 时评分]
        │
        └── gh pr create（在代码仓库创建 PR）
              │
              ▼
    汇总累积的提示词 + AI 评分（100分）
              │
              ▼
    在提示词仓库创建 PR
              │
              ▼
    团队成员审查提示词质量
```

不在项目仓库中留下任何痕迹。所有审查 PR 都在独立仓库中创建（例如 `my-org/ai-sessions`）。

---

## 评分系统

8项标准，100分满分。单次 LLM 调用评估。

| 标准 | 分值 | 说明 |
|------|------|------|
| 目标清晰度 (Goal Clarity) | 20 | 目标是否具体？结果是否与意图一致？ |
| 范围控制 (Scope Control) | 15 | 是否设定边界？是否明确约束？是否有超范围更改？ |
| 上下文充分性 (Context Sufficiency) | 15 | 是否提供了足够的背景（包括参考代码/模式）？ |
| 退出标准 (Exit Criteria) | 10 | 是否明确并遵守了完成/停止条件？ |
| 分解 (Decomposition) | 10 | 复杂任务是否被适当拆分？ |
| 验证策略 (Verification Strategy) | 10 | 是否指定了验证方法？ |
| 迭代质量 (Iteration Quality) | 10 | 后续请求是否具体明确？ |
| 复杂度匹配 (Complexity Fit) | 10 | 提示词的精细度是否适合任务复杂度？ |

### 差距模型

| 差距 | 说明 | 评估者 |
|------|------|--------|
| Gap 1 | 意图 → 提示词 | 仅人类 |
| Gap 2 | 提示词 → 代码 | AI 可辅助 |

---

## PR 示例

```markdown
## Score: 73/100 — JWT 刷新逻辑重构

> Prompts: 6 | Duration: ~35 min | LLM scored

## Prompt Quality Scorecard

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| ✅ | Goal Clarity | 18/20 | █████████░ | 目标明确 |
| ❌ | Exit Criteria | 4/10 | ████░░░░░░ | 无停止条件 |
| ...

## What Was Produced
> 5 files changed, +142 −38

## Improvement Suggestions
### Exit Criteria (4/10)
> Claude 超出范围。Prompt Gap：未指定退出标准。
```

---

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| 安装后 Hook 不工作 | 重启 Claude Code 会话以重新加载插件 hook |
| 配置错误 | 删除 `~/.claude/prompt-review.config.json` 后运行 `/setup` 重新配置 |

---

## 要求

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/)（用于创建 PR）
- Git

---

## 许可证

MIT — 参见 [LICENSE](LICENSE)
