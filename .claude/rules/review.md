---
globs: "**/*.swift"
---

# Code Review Process

## 주요 변경 시 리뷰 프로세스

1. **구현 완료 후**: `make verify` 통과 확인
2. **리뷰 요청**: `/review` 또는 `hoyeon:code-reviewer` (다중 모델 교차 검증)
3. **UI 변경 시**: 3-Agent QA (Visual/UX + Code Quality + Mobile Responsive)

## 교차 검증 도구

- `/review` — PR diff 기반 구조적 리뷰
- `hoyeon:code-reviewer` — Gemini + Codex + Claude 교차 리뷰, SHIP/NEEDS_FIXES 판정
- `/tribunal` — Risk/Value/Feasibility 3관점 리뷰
- `/qa` — 브라우저 기반 시각 검증 (웹 컴포넌트 해당 시)

## 리뷰 필수 대상

- Firestore 스키마/컬렉션 변경
- 인증/가족공유 로직 변경
- AI 가드레일 관련 코드
- 새 서비스 클래스 추가
