# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | **한국어** | [日本語](README.ja.md) | [中文](README.zh.md)

**Claude Code를 위한 프롬프트 리뷰. 코드 리뷰는 결과를 봅니다 — 프롬프트 리뷰는 원인을 봅니다.**

---

## 빠른 시작

**1단계: 설치**
```
/plugin marketplace add https://github.com/SDB016/prompt-craft
/plugin install prompt-craft
```

**2단계: 셋업 (설치 직후 실행)**
```
/setup           # 리뷰 저장소를 묻고 → 자동으로 모든 설정 완료
```

**3단계: 사용**
```
git push         # 프롬프트 자동 캡처
/review          # 프롬프트 리뷰 PR 생성
/score           # 로컬 스코어링 (PR 생성 없음)
```

`/setup`이 리뷰 저장소를 묻고 나머지는 자동으로 설정합니다. 이후 매 `git push`마다 프롬프트가 자동 캡처되고, `gh pr create` 시 점수가 매겨집니다.

> **참고:** 설치 후 Claude Code를 재시작해야 push hook이 활성화됩니다. `/setup`을 건너뛰면 매 세션 시작 시 알림이 표시됩니다.

---

## 왜 Prompt Craft인가?

- **팀 레벨 프롬프트 품질** - GitHub PR을 통해 서로의 AI 프롬프트를 리뷰
- **자동 스코어링** - 8개 기준, 100점 만점, 단일 LLM 호출
- **프로젝트 무흔적** - 모든 리뷰 PR은 별도 저장소로, 프로젝트에 흔적 없음
- **코드 리뷰의 보완재** - 코드는 증거, 프롬프트는 원인
- **보안 우선** - 전송 전 미리보기, 자동 시크릿 스캐닝

---

## 스킬

| 스킬 | 용도 |
|------|------|
| `/review` | 팀 피드백을 위한 프롬프트 리뷰 PR 생성 |
| `/score` | 로컬 스코어링 + 개선 팁 (`--verbose`) |
| `/insights` | 점수 트렌드, 고점수 패턴, 세션 비교 |
| `/prompt-guide` | 작업 전 프롬프트 가이드 + 재사용 템플릿 |
| `/setup-project` | 프로젝트별 캡처 설정 (활성화, 비활성화, 커스텀 저장소) |

### review

| 명령어 | 동작 |
|--------|------|
| `/review` | 프롬프트 리뷰 PR 생성 |
| `/review --push` | Hook 트리거 push 캡처 |
| `/review --status` | 설정 + 최근 PR 표시 |
| `/review --doctor` | 사전 요건 확인 (git, gh, jq) |
| `/review --setup` | 설정 재구성 |

### insights

| 명령어 | 동작 |
|--------|------|
| `/insights` | 시간별 점수 트렌드 |
| `/insights --team` | 전체 작성자 트렌드 |
| `/insights patterns` | 고점수 프롬프트 패턴 추출 |
| `/insights compare #1 #2` | 두 리뷰 세션 비교 |

### prompt-guide

| 명령어 | 동작 |
|--------|------|
| `/prompt-guide` | 맥락 기반 프롬프트 작성 팁 |
| `/prompt-guide template save/list/use/delete` | 재사용 템플릿 관리 |

### setup-project

| 명령어 | 동작 |
|--------|------|
| `/setup-project` | 현재 프로젝트 캡처 상태 표시 |
| `/setup-project on` | 현재 프로젝트 캡처 활성화 |
| `/setup-project on --repo R` | 특정 리뷰 저장소로 캡처 활성화 |
| `/setup-project off` | 캡처 비활성화 (자동 건너뜀) |
| `/setup-project list` | 전체 프로젝트 설정 표시 |
| `/setup-project reset` | 건너뛴 프로젝트 다시 질문 활성화 |

### 자동 흐름

| 이벤트 | 동작 | 프롬프트 저장소 |
|--------|------|----------------|
| `git push` (Claude Code 내부) | 프롬프트 + diff 캡처 | **커밋만** (PR 없음) |
| `gh pr create` (Claude Code 내부) | 집계 + 스코어링 | **PR 생성** |
| `/review` (수동) | 원하는 시점에 PR 생성 | **PR 생성** |

---

## 작동 방식

```
[개발 중 — 매 push마다 기록]

  Claude Code로 작업
        │
        ├── git push #1 → 프롬프트 저장소에 커밋 (프롬프트 + diff 기록)
        ├── git push #2 → 프롬프트 저장소에 커밋 (추가 기록)
        ├── git push #3 → 프롬프트 저장소에 커밋 (추가 기록)
        │
[기능 완료 — PR 시점에 스코어링]
        │
        └── gh pr create (코드 저장소에 PR)
              │
              ▼
    누적된 프롬프트 집계 + AI 스코어링 (100점)
              │
              ▼
    프롬프트 저장소에 PR 생성
              │
              ▼
    팀원이 프롬프트 품질 리뷰
```

프로젝트 저장소에 흔적을 남기지 않습니다. 모든 리뷰 PR은 별도 저장소(예: `my-org/ai-sessions`)에 생성됩니다.

---

## 스코어링 시스템

8개 기준, 100점 만점. 단일 LLM 호출로 평가.

| 기준 | 배점 | 설명 |
|------|------|------|
| 목표 명확성 (Goal Clarity) | 20 | 목표가 구체적이고 결과가 의도와 일치하는가? |
| 범위 통제 (Scope Control) | 15 | 경계가 설정되고 제약이 명시되었으며 범위 밖 변경이 없는가? |
| 맥락 충분성 (Context Sufficiency) | 15 | 충분한 배경(참조 코드/패턴 포함)이 제공되었는가? |
| 종료 기준 (Exit Criteria) | 10 | 완료/중단 조건이 명시되고 준수되었는가? |
| 분해 (Decomposition) | 10 | 복잡한 작업이 적절히 분할되었는가? |
| 검증 전략 (Verification Strategy) | 10 | 검증 방법이 명시되었는가? |
| 반복 품질 (Iteration Quality) | 10 | 후속 요청이 구체적이고 명확한가? |
| 복잡도 적합 (Complexity Fit) | 10 | 프롬프트 정교함이 작업 복잡도에 적합한가? |

### 갭 모델

| 갭 | 설명 | 평가자 |
|----|------|--------|
| Gap 1 | 의도 → 프롬프트 | 사람만 가능 |
| Gap 2 | 프롬프트 → 코드 | AI 보조 가능 |

---

## PR 예시

```markdown
## Score: 73/100 — JWT refresh 로직 리팩토링

> Prompts: 6 | Duration: ~35 min | LLM scored

## Prompt Quality Scorecard

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| ✅ | Goal Clarity | 18/20 | █████████░ | 명확한 목표 명시 |
| ❌ | Exit Criteria | 4/10 | ████░░░░░░ | 중단 조건 없음 |
| ...

## What Was Produced
> 5 files changed, +142 −38

## Improvement Suggestions
### Exit Criteria (4/10)
> Claude가 범위를 초과함. Prompt Gap: 종료 기준 미명시.
```

---

## 문제 해결

| 문제 | 해결 |
|------|------|
| 설치 후 Hook이 작동하지 않음 | Claude Code 세션을 재시작하여 플러그인 hook을 다시 로드 |
| 설정 오류 | `~/.claude/prompt-review.config.json` 삭제 후 `/setup` 실행하여 재설정 |

---

## 요구 사항

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/) (PR 생성용)
- Git

---

## 라이선스

MIT — [LICENSE](LICENSE) 참조
