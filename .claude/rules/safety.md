---
globs: "**/*.swift"
---

# Safety Rules (Must NOT Do)

- Baby.gender Optional 변경 금지
- AIGuardrailService 금지어 수정 금지
- 백분위 의학적 판단 텍스트 금지
- 외부 차트 라이브러리 금지 (Apple Charts만)
- 데이터 로딩/저장 시 authVM.currentUserId 직접 사용 금지
- AI 가드레일: AIGuardrailService.prohibitedRules 수정 금지
