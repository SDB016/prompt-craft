# prompt-review Expansion Brainstorming Comprehensive Report

> Date: 2026-03-08
> Participants: Product Analyst, Architect, UX Designer, Strategic Planner, Critic
> Distribution Strategy: GitHub Marketplace (leveraging the existing marketplace)

---

## Core Insights

**"The Compound Interest Effect of Accumulation"** — The current value of prompt-review is "saving one session," but the real value emerges when dozens or hundreds of sessions accumulate over time.

**"Local-First as a Moat"** — Since code never passes through external servers, there is a privacy advantage. The barrier to enterprise adoption is extremely low.

**"Zero Additional Cost"** — Data lives on the user's local machine or GitHub, and analysis is performed by Claude, which the user is already subscribed to.

---

## Top 10 Expansion Ideas (Consensus Ranking)

### Tier 1: Immediately Implementable (S effort, High ROI)

| # | Feature | Description | Impact |
|---|---------|-------------|--------|
| 1 | **Session Search** | `search "redis cache"` — Natural language search across past sessions. gh CLI + LLM semantic matching | 4/5 |
| 2 | **Auto-Tag Enrichment** | LLM automatically assigns tags/labels to existing sessions. `--retag-all` | 3/5 |
| 3 | **Quick Capture** | `--quick` 30-second capture mode. Just one line for the decision + one line for the rationale | 4/5 |
| 4 | **Session Continuation** | `--resume #42` loads context from a past session | 4/5 |

### Tier 2: Core Differentiators (M effort)

| # | Feature | Description | Impact |
|---|---------|-------------|--------|
| 5 | **Context Preloader** | Automatically surfaces relevant past sessions at session start. "Claude remembers" | 5/5 |
| 6 | **Gotcha Database** | Matches past learnings/gotchas to the current project and sends alerts | 5/5 |
| 7 | **Session Insights** | Automatically generates weekly/monthly retrospective reports | 5/5 |
| 8 | **Session Templates** | Tailored capture formats for bug/arch/refactor/learn/spike | 4/5 |

### Tier 3: Team/Platform Expansion (L effort)

| # | Feature | Description | Impact |
|---|---------|-------------|--------|
| 9 | **Team Session Feed** | Shared archive repo. Team digest, expert discovery, knowledge gap analysis | 5/5 |
| 10 | **Prompt Pattern Library** | Automatic extraction and sharing of effective prompt patterns | 4/5 |

---

## Architecture Evolution Roadmap

### Phase 1: Foundation (Immediate to 3 months)

```
Current: sessions/YYYY-MM-DD-slug.md (flat markdown)

Improved:
sessions/
  index.json                    # Full session index
  tags.json                     # Tag-to-session mapping
  2026/03/
    08-feature-auth.md          # Includes YAML frontmatter
```

**YAML Frontmatter Addition:**
```yaml
---
id: session-2026-0308-a1b2c3
timestamp: 2026-03-08T14:30:00Z
duration_minutes: 45
project: myorg/myapp
files_touched: [src/auth.ts, src/middleware.ts]
tags: [authentication, middleware, bugfix]
outcome: success
related_sessions: [session-2026-0305-d4e5f6]
---
```

**Key Point**: Gain the benefits of structured data while maintaining markdown compatibility. This serves as the foundation for all subsequent extensions.

### Phase 2: Team Expansion (3 to 6 months)

- MCP server integration (Slack, Linear)
- Team configuration file `.prompt-review/team-config.yml`
- Team dashboard (GitHub Pages or PR-based)
- Automatic ADR generation

### Phase 3: Platformization (6 months to 1 year)

- Semantic search (local SQLite)
- Derived skill ecosystem (session-onboard, session-review)
- Community prompt marketplace
- Developer growth reports

---

## GitHub Marketplace Distribution Strategy

Premised on leveraging the existing marketplace:

### Packaging
```
GitHub Marketplace listing:
  Name: prompt-review
  Category: Developer Tools / AI Productivity
  Type: Claude Code Skill

  Tiers:
    Free:            Unlimited session capture, basic search, secret scanning
    Pro ($8/mo):     AI insights, prompt analysis, custom templates
    Team ($20/mo/user): Team feed, shared library, dashboard
```

### Installation Flow (Marketplace to Local)
```
1. Click "Install" on GitHub Marketplace
2. gh extension install prompt-review (or copy the skill)
3. /prompt-review --setup (initial setup wizard)
4. Ready to use immediately
```

### Marketplace Differentiators
- Runs locally (no data leaves the machine)
- Native Claude Code integration
- GitHub PR-based archive (GitHub ecosystem friendly)

---

## Critic's Key Counterarguments & Responses

| Counterargument | Risk Level | Response |
|-----------------|------------|----------|
| "Once 100 PRs pile up, nobody will look at them" | High | Session Search + Context Preloader create "moments where the past helps the present" |
| "GitHub PRs are not suited for knowledge management" | Medium | Add a metadata layer while maintaining markdown compatibility. PRs serve as the "transport layer"; search is handled separately |
| "Users won't form the habit" | High | --quick 30-second mode + smart suggestions (automatic prompt at session end) |
| "What if Anthropic releases this as a native feature?" | Critical | Expand to support multiple AI tools + differentiate through team/organization-level value |
| "Dependency on the unofficial JSONL format" | Medium | Capture based on current conversation context (no JSONL parsing needed). Real-time capture hybrid approach |

### Critic's Suggested Validation Priorities
1. Interview 5 existing users to measure actual revisit rates
2. Run a comparison experiment with a minimal version (local markdown summary)
3. Collect 2 weeks of usage data before making expansion decisions

---

## User Retention Psychological Model

| Timeframe | Psychological Hook | Corresponding Feature |
|-----------|--------------------|-----------------------|
| First use | "It's this simple?" | --quick 30-second capture |
| Weeks 2-3 | "I can actually find it!" | search + --recall |
| Months 1-2 | "I'm contributing to the team" | --share + team feed |
| 6 months+ | "This is my technical autobiography" | --growth + --viz |

**Key Point**: You must create "moments where the past helps the present." Users who experience that moment will not leave.

---

## Execution Recommendations

### Immediate (This Week)
- [x] MVP stabilization (security/stability fixes completed)
- [ ] Add YAML frontmatter metadata
- [ ] --quick 30-second capture mode
- [ ] Basic Session Search implementation

### Short-Term (1 Month)
- [ ] Prepare GitHub Marketplace listing
- [ ] Implement Context Preloader
- [ ] Session Templates (bug/arch/learn)
- [ ] Interview 5 users

### Medium-Term (3 Months)
- [ ] Team features (shared repo, team feed)
- [ ] Gotcha Database
- [ ] Session Insights (weekly reports)
- [ ] Separate Pro tier features

---

## Vision Summary

> **prompt-review is not just a session capture tool.**
> **It is a system where development organization knowledge accumulates, is shared, and evolves in the age of AI.**

- 6 months from now: "My AI sessions are automatically recorded and searchable"
- 1 year from now: "Our team's AI usage know-how is accumulated as an asset"
- 2 years from now: "Standard infrastructure for AI-native development organizations"
