# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[English](README.md) | **한국어** | [日本語](README.ja.md) | [中文](README.zh.md)

**Claude Code를 위한 프롬프트 리뷰 — 코드 리뷰는 결과를 봅니다, 프롬프트 리뷰는 원인을 봅니다.**

> 서로의 코드를 리뷰하잖아요. 프롬프트도 리뷰하면 어떨까요?
>
> Prompt Craft는 Claude Code에서 사용한 프롬프트를 캡처하고, 8개 품질 기준으로 스코어링한 뒤,
> 전용 리뷰 저장소에 GitHub PR을 생성합니다 — 팀이 코드 자체가 아닌 코드를 만든 *지시사항*에 피드백을 줄 수 있습니다.

---

## 이게 뭘 하는 건가요

```
평소처럼 Claude Code로 작업하세요.
추가 단계 없음. 중단 없음.

                                            ┌─────────────────────────────┐
  git push  ──→  메타데이터 무음 기록        │  ~/.claude/pushlog.jsonl    │
  git push  ──→  메타데이터 무음 기록        │  (네트워크 없음, 블로킹 없음) │
  git push  ──→  메타데이터 무음 기록        └─────────────────────────────┘
                                                        │
  /review   ──→  세션에서 프롬프트 수집                    │
             ──→  8개 기준으로 스코어링       ◄─────────┘
             ──→  리뷰 저장소에 PR 생성

                        ▼

  ┌─ 리뷰 저장소의 PR ───────────────────────────────────┐
  │                                                      │
  │  PR body       Score badge + Review Focus            │
  │                                                      │
  │  Files Changed:                                      │
  │    prompts.md   ← 리뷰어가 라인 코멘트 다는 곳         │
  │    summary.md   ← 스코어카드, 개선안, 메타데이터        │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

**개발 중 마찰 제로.** Push hook은 무음 (<100ms, 승인 없음).
무거운 작업(스코어링, PR 생성)은 `/review` 실행 시에만 발생합니다.

**프로젝트 무흔적.** 프로젝트 저장소에는 아무것도 쓰지 않습니다. 모든 리뷰 PR은 별도 저장소(예: `my-org/ai-sessions`)에 생성됩니다.

---

## 빠른 시작

**1단계: 설치**
```
/install-plugin https://github.com/sdb016/prompt-craft
```

**2단계: 셋업 (설치 직후 실행)**
```
/setup           # 리뷰 저장소를 묻고 → 자동으로 모든 설정 완료
```

**3단계: 사용**
```
# 평소처럼 작업... 코드 push... 준비되면:
/review          # 팀 피드백을 위한 프롬프트 리뷰 PR 생성
/score           # 로컬 스코어링만 (PR 없음, 즉시 피드백)
```

> **참고:** 설치 후 Claude Code를 재시작해야 push hook이 활성화됩니다.

---

## 왜 Prompt Craft인가?

| 문제 | Prompt Craft가 도와주는 방법 |
|------|----------------------------|
| "Claude가 범위를 벗어났어" | 프롬프트 리뷰가 누락된 종료 기준과 범위 제약을 밝혀줌 |
| "저 사람은 Claude를 어떻게 그렇게 잘 쓰지?" | 팀이 훌륭한 결과를 만든 정확한 프롬프트 시퀀스를 볼 수 있음 |
| "프롬프트가 되긴 하는데 비효율적인 것 같아" | 8개 기준 스코어링 + 구체적인 리라이트 제안 |
| "코드 리뷰는 결과만 잡아, 원인을 못 잡아" | 프롬프트 리뷰가 코드를 만든 *지시사항*을 잡아줌 |
| "개선하고 싶은데 뭘 바꿔야 할지 모르겠어" | 프롬프트별 미니 스코어가 어떤 프롬프트를 개선해야 하는지 정확히 알려줌 |

---

## 스킬

| 스킬 | 용도 |
|------|------|
| `/review` | 팀 피드백을 위한 프롬프트 리뷰 PR 생성 |
| `/score` | 로컬 스코어링 + 개선 팁 (즉시, PR 없음) |
| `/insights` | 점수 트렌드, 고점수 패턴, 세션 비교 |
| `/prompt-guide` | 작업 전 프롬프트 가이드 + 재사용 템플릿 |
| `/setup-project` | 프로젝트별 캡처 설정 (활성화, 비활성화, 커스텀 저장소) |

### review

| 명령어 | 동작 |
|--------|------|
| `/review` | 프롬프트 리뷰 PR 생성 |
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

---

## 작동 방식

### 개발 중 (자동, 무음)

Claude Code 내에서 `git push`할 때마다 로컬 로그 파일에 한 줄을 무음으로 추가합니다. 네트워크 없음, AI 없음, 블로킹 없음 — 눈치채지도 못합니다.

### 리뷰 시 (온디맨드)

`/review`를 실행하면 (또는 `gh pr create`가 감지되면), Prompt Craft가:

1. 로컬 로그에서 push 메타데이터를 읽음
2. 현재 세션에서 모든 프롬프트를 수집
3. 8개 품질 기준으로 스코어링 (단일 LLM 호출)
4. 리뷰 저장소에 두 파일 생성:
   - **`prompts.md`** — 프롬프트 시퀀스 (plain text, 리뷰어가 라인 코멘트 다는 곳)
   - **`summary.md`** — 스코어카드, 코드 임팩트, 개선 제안, 메타데이터
5. Files Changed를 가리키는 간결한 PR body로 PR 오픈

### 자동 흐름

| 이벤트 | 동작 | 위치 |
|--------|------|------|
| `git push` | push 메타데이터 무음 기록 | 로컬 JSONL (<100ms) |
| `gh pr create` | 프롬프트 스코어링 + 리뷰 PR 생성 | 리뷰 저장소 PR |
| `/review` (수동) | 원하는 시점에 리뷰 PR 생성 | 리뷰 저장소 PR |
| `/score` (수동) | 로컬 스코어링, 결과 캐시 | 로컬만 (즉시) |

---

## PR 구조

리뷰어는 **Files Changed** 탭에서 두 파일을 봅니다:

| 파일 | 용도 | 리뷰어 행동 |
|------|------|------------|
| **`prompts.md`** | 프롬프트 시퀀스 (plain text) | 특정 프롬프트에 라인 코멘트 달기 |
| **`summary.md`** | 스코어카드, 코드 임팩트, 개선안, 메타데이터 | 맥락과 스코어링 세부 확인 |

PR body는 간결한 요약입니다: Score badge + Review Focus + "Files Changed를 열어 리뷰하세요."

### 예시

**PR body:**
```markdown
## 🔵 Score: 74/100 — JWT refresh 로직 리팩토링

> Prompts: 6 | Duration: ~38 min | Session: 2026-03-08 by @dev-alice

### Review Focus
Exit Criteria 4/10 — 프롬프트 #2, #3에 중단 조건이 없어
Claude가 범위를 벗어나 파일을 수정함.

### How to Review
| File | What's inside | Action |
|------|---------------|--------|
| prompts.md | 프롬프트 시퀀스 | 라인 코멘트 달기 |
| summary.md | 스코어카드 + 개선안 | 맥락 확인 |
```

**prompts.md** (Files Changed에서):
```markdown
## Review Focus
Exit Criteria 4/10 — 프롬프트 #2, #3에 중단 조건이 없어...

## Prompt Sequence

### Prompt 1 🟢
src/auth/refresh.ts의 JWT refresh 로직을 리팩토링해줘.
Context: 지난주에 mutex 방식을 쓰기로 결정했어...
Done when: src/auth/refresh.ts가 refreshToken(userId)를 export...

Goal 20/20 · Exit 9/10 · Scope 12/15 · Context 14/15
```

---

## 스코어링 시스템

8개 기준, 100점 만점. 단일 LLM 호출로 평가.

| 기준 | 배점 | 평가 내용 |
|------|------|----------|
| 목표 명확성 (Goal Clarity) | 20 | 목표가 구체적이고 결과가 의도와 일치하는가? |
| 범위 통제 (Scope Control) | 15 | 경계가 설정되고 제약이 명시되었는가? |
| 맥락 충분성 (Context Sufficiency) | 15 | 충분한 배경이 제공되었는가? |
| 종료 기준 (Exit Criteria) | 10 | 완료/중단 조건이 명시되고 준수되었는가? |
| 분해 (Decomposition) | 10 | 복잡한 작업이 적절히 분할되었는가? |
| 검증 전략 (Verification Strategy) | 10 | 검증 방법이 명시되었는가? |
| 반복 품질 (Iteration Quality) | 10 | 후속 요청이 구체적이고 명확한가? |
| 복잡도 적합 (Complexity Fit) | 10 | 프롬프트 정교함이 작업 복잡도에 적합한가? |

**등급:** 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor

### 프롬프트 갭 모델

| 갭 | 의미 | 평가자 |
|----|------|--------|
| Gap 1: 의도 → 프롬프트 | 프롬프트가 실제 원하는 것을 담았는가? | 사람 (리뷰를 통해) |
| Gap 2: 프롬프트 → 코드 | 프롬프트 결함이 코드 결함을 유발했는가? | AI (원인→결과 체인) |

---

## 문제 해결

| 문제 | 해결 |
|------|------|
| 설치 후 Hook이 작동하지 않음 | Claude Code 세션을 재시작하여 플러그인 hook 재로드 |
| 설정 오류 | `~/.claude/prompt-review.config.json` 삭제 후 `/setup` 실행하여 재설정 |
| `/review`에서 프롬프트가 안 보임 | 작업한 동일 세션에서 `/review` 실행. 또는 `/score`를 먼저 실행하여 결과 캐시 |

---

## 요구 사항

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/) (PR 생성용)
- Git

---

## 라이선스

MIT — [LICENSE](LICENSE) 참조
