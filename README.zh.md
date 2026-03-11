# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **中文**

**Claude Code 的提示词审查 — 代码审查看结果，提示词审查看原因。**

> 你们互相审查代码，为什么不审查彼此的提示词呢？
>
> Prompt Craft 捕获你在 Claude Code 中使用的提示词，按8项质量标准评分，
> 并在专用审查仓库中创建 GitHub PR — 让团队可以对产生代码的*指令*提供反馈，
> 而不仅仅是代码本身。

---

## 它做什么

```
像往常一样使用 Claude Code 工作。
无额外步骤。无中断。

                                            ┌─────────────────────────────┐
  git push  ──→  静默记录元数据              │  ~/.claude/pushlog.jsonl    │
  git push  ──→  静默记录元数据              │  (无网络，无阻塞)            │
  git push  ──→  静默记录元数据              └─────────────────────────────┘
                                                        │
  /review   ──→  从会话中收集提示词                       │
             ──→  按8项标准评分              ◄─────────┘
             ──→  在审查仓库创建 PR

                        ▼

  ┌─ 审查仓库中的 PR ────────────────────────────────────┐
  │                                                      │
  │  PR body       Score badge + Review Focus            │
  │                                                      │
  │  Files Changed:                                      │
  │    prompts.md   ← 审查者在此添加行级评论               │
  │    summary.md   ← 评分卡、改进建议、元数据              │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

**开发过程零摩擦。** Push hook 静默运行（<100ms，无需批准）。
重量级工作（评分、PR 创建）仅在运行 `/review` 时发生。

**零项目痕迹。** 不会在项目仓库中写入任何内容。所有审查 PR 都在独立仓库中创建（例如 `my-org/ai-sessions`）。

---

## 快速开始

**步骤1: 安装**
```
/install-plugin https://github.com/sdb016/prompt-craft
```

**步骤2: 设置（安装后立即执行）**
```
/setup           # 询问审查仓库 → 自动完成所有配置
```

**步骤3: 使用**
```
# 正常工作... push 代码... 准备好后:
/review          # 创建提示词审查 PR 供团队反馈
/score           # 仅本地评分（无 PR，即时反馈）
```

> **注意：** 首次安装后需重启 Claude Code 以激活 push hook。

---

## 为什么选择 Prompt Craft？

| 问题 | Prompt Craft 如何帮助 |
|------|---------------------|
| "Claude 超出了范围" | 提示词审查揭示缺失的退出标准和范围约束 |
| "他们是怎么让 Claude 做到那样的？" | 团队可以看到产生优秀结果的精确提示词序列 |
| "我的提示词能用但感觉低效" | 8项标准评分 + 具体的重写建议 |
| "代码审查只能捕捉结果，捕捉不到原因" | 提示词审查捕捉产生代码的*指令* |
| "想改进但不知道该改什么" | 每个提示词的迷你评分精确指出哪些提示词需要改进 |

---

## 技能

| 技能 | 用途 |
|------|------|
| `/review` | 创建提示词审查 PR 供团队反馈 |
| `/score` | 本地评分 + 改进建议（即时，无 PR） |
| `/insights` | 分数趋势、高分模式、会话比较 |
| `/prompt-guide` | 任务前提示词指南 + 可复用模板 |
| `/setup-project` | 项目级捕获设置（启用、禁用、自定义仓库） |

### review

| 命令 | 动作 |
|------|------|
| `/review` | 创建提示词审查 PR |
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

---

## 工作原理

### 开发中（自动、静默）

每次在 Claude Code 中 `git push` 时，静默向本地日志文件追加一行。无网络、无 AI、无阻塞 — 你甚至不会注意到。

### 审查时（按需）

运行 `/review`（或检测到 `gh pr create`）时，Prompt Craft 会:

1. 从本地日志读取 push 元数据
2. 从当前会话收集所有提示词
3. 按8项质量标准评分（单次 LLM 调用）
4. 在审查仓库创建两个文件:
   - **`prompts.md`** — 提示词序列（纯文本，审查者在此添加行级评论）
   - **`summary.md`** — 评分卡、代码影响、改进建议、元数据
5. 以简洁的 PR body 打开 PR，指向 Files Changed

### 自动流程

| 事件 | 动作 | 位置 |
|------|------|------|
| `git push` | 静默记录 push 元数据 | 本地 JSONL (<100ms) |
| `gh pr create` | 提示词评分 + 创建审查 PR | 审查仓库 PR |
| `/review`（手动） | 在需要时创建审查 PR | 审查仓库 PR |
| `/score`（手动） | 本地评分，缓存结果 | 仅本地（即时） |

---

## PR 结构

审查者在 **Files Changed** 标签页看到两个文件:

| 文件 | 目的 | 审查者操作 |
|------|------|-----------|
| **`prompts.md`** | 提示词序列（纯文本） | 对特定提示词添加行级评论 |
| **`summary.md`** | 评分卡、代码影响、改进建议、元数据 | 查看上下文和评分详情 |

PR body 是简洁的摘要: Score badge + Review Focus + "打开 Files Changed 开始审查"

---

## 评分系统

8项标准，100分满分。单次 LLM 调用评估。

| 标准 | 分值 | 评估内容 |
|------|------|---------|
| 目标清晰度 (Goal Clarity) | 20 | 目标是否具体？结果是否与意图一致？ |
| 范围控制 (Scope Control) | 15 | 是否设定边界？是否明确约束？ |
| 上下文充分性 (Context Sufficiency) | 15 | 是否提供了足够的背景？ |
| 退出标准 (Exit Criteria) | 10 | 是否明确并遵守了完成/停止条件？ |
| 分解 (Decomposition) | 10 | 复杂任务是否被适当拆分？ |
| 验证策略 (Verification Strategy) | 10 | 是否指定了验证方法？ |
| 迭代质量 (Iteration Quality) | 10 | 后续请求是否具体明确？ |
| 复杂度匹配 (Complexity Fit) | 10 | 提示词的精细度是否适合任务复杂度？ |

**等级:** 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor

### 提示词差距模型

| 差距 | 含义 | 评估者 |
|------|------|--------|
| Gap 1: 意图 → 提示词 | 提示词是否捕捉了你真正想要的？ | 人类（通过审查） |
| Gap 2: 提示词 → 代码 | 提示词缺陷是否导致了代码缺陷？ | AI（因果链） |

---

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| 安装后 Hook 不工作 | 重启 Claude Code 会话以重新加载插件 hook |
| 配置错误 | 删除 `~/.claude/prompt-review.config.json` 后运行 `/setup` 重新配置 |
| `/review` 未显示提示词 | 从工作的同一会话运行 `/review`。或先运行 `/score` 缓存结果 |

---

## 要求

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/)（用于创建 PR）
- Git

---

## 许可证

MIT — 参见 [LICENSE](LICENSE)
