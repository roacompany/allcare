# BabyCare 기능 강화 분석 보고서

> 25개 기존 기능 분석 + 경쟁앱 벤치마크 기반 강화 방안
> 2026-04-14 (작성) / 2026-04-15 (전체 12개 항목 완료)

## 진행 상태 (2026-04-15 기준)

| # | Tier | 기능 | 상태 | 커밋/근거 |
|---|------|------|------|-----------|
| 1 | T1 | 수유 예측 고도화 | ✅ 완료 | FeedingPredictionService v2 (day/night) |
| 2 | T1 | 주간 인사이트 리포트 | ✅ 완료 | WeeklyInsightService |
| 3 | T1 | 성장 차트 강화 | ✅ 완료 | feat(growth) WHO AreaMark v2 |
| 4 | T1 | 대시보드 인사이트 카드 | ✅ 완료 | `96b7490` InsightService 4종 |
| 5 | T2 | 수면 분석 + 퇴행 감지 | ✅ 완료 | `e8c3f1d` SleepAnalysisService |
| 6 | T3 | 예방접종 알림 강화 | ✅ 완료 | `478bf8d` D-day + 단계별 푸시 |
| 7 | T2 | 할일/루틴 자동화 | ✅ 완료 | done/todo-routine-automation |
| 8 | T2 | 일기 자동 요약 | ✅ 완료 | `7da1756` DiaryAnalysisService |
| 9 | T3 | 알레르기 추적 강화 | ✅ 완료 | `2bb765e` + `5a4fa40` (90일 fetch) |
| 10 | T2 | 병원 리포트 강화 | ✅ 완료 | `0497880` HospitalChecklistService |
| 11 | T3 | 제품 추천 | ✅ 완료 | `706d59d` ProductRecommendationService |
| 12 | T3 | 위젯 강화 | ✅ 완료 | `f08f078` + `5a4fa40` (baby sync) |

**누적**: 테스트 107→195 (+88), arch-test 0 violations 유지, harness-score 96% Grade A 유지.

---

## (이하 원본 보고서)


---

## 강화 가능 기능 목록 (우선순위순)

### Tier 1: 높은 임팩트 + 기존 인프라 활용 (바로 실행 가능)

---

#### 1. 수유 예측 고도화 (FeedingPredictionService)

**현재**: 월령 기반 고정 간격 (0개월=2시간, 6개월=4시간, 12개월+=5시간)
**문제**: 모든 아기에게 같은 간격 적용. 실제 패턴 미반영.

**강화 방안**:
- 최근 7일 실제 수유 간격 평균으로 개인화 (데이터 이미 있음)
- 시간대별 패턴 학습 (낮 vs 밤 수유 간격 차이)
- 대시보드에 "다음 수유 예상: 2:30 PM (약 40분 후)" 표시 강화
- 오버듀 시 푸시 알림 자동 발송

**근거**: Huckleberry의 SweetSpot이 가장 높은 평가 받는 기능. 우리는 데이터가 이미 있고 FeedingPredictionService만 개선하면 됨.
**작업량**: 중 (1-2일) | **파일**: FeedingPredictionService.swift, DashboardView+Summary.swift

---

#### 2. 주간 인사이트 리포트 (PatternAnalysisService)

**현재**: 패턴 분석은 사용자가 Stats 탭에서 직접 열어야 봄. 푸시/자동 요약 없음.
**문제**: 분석 데이터는 풍부하나 사용자에게 능동적으로 전달하지 않음.

**강화 방안**:
- 매주 월요일 "지난주 육아 리포트" 푸시 알림 + 인앱 카드
- 핵심 변화 3가지 자동 추출 ("수유 횟수 15% 증가", "수면 시간 안정화", "배변 패턴 정상")
- 전주 대비 변화량 시각화 (화살표 + 숫자)
- 대시보드 상단에 "이번 주 하이라이트" 카드 추가

**근거**: 경쟁앱 공통 리텐션 드라이버. PatternAnalysisService에 비교 데이터 이미 있음.
**작업량**: 중 (2-3일) | **파일**: PatternAnalysisService.swift, NotificationService.swift, DashboardView+Summary.swift

---

#### 3. 성장 차트 강화 (GrowthView + PercentileCalculator)

**현재**: WHO 백분위 계산 + 기본 차트. 성장 속도 알림만 존재.
**문제**: 차트가 단순 점 표시. 시간에 따른 추세선/백분위 밴드 미표시.

**강화 방안**:
- 성장 곡선 차트: WHO 3/15/50/85/97 백분위 밴드 위에 아기 데이터 오버레이
- 성장 속도 트렌드 차트 (최근 3개월 기울기)
- "또래 평균 대비" 위치 한눈에 표시 (상위 XX%)
- 예측 곡선: 현재 성장률 유지 시 6개월 후 예상 수치

**근거**: Sprout Baby의 핵심 차별점. PercentileCalculator에 LMS 데이터 완비. Apple Charts만으로 구현 가능.
**작업량**: 중 (2-3일) | **파일**: GrowthView+Charts.swift, GrowthView+Percentile.swift, PercentileCalculator.swift

---

#### 4. 대시보드 인사이트 카드 (DashboardView)

**현재**: 오늘 요약 (수유 횟수, 수면 시간, 기저귀 횟수) + 타임라인
**문제**: 숫자만 나열. "그래서 뭘 해야 해?"에 대한 답이 없음.

**강화 방안**:
- 컨텍스트 인사이트 카드: "오늘 수유 3회 — 평소보다 1회 적어요"
- 수면 예측: "낮잠 시간이 다가오고 있어요 (약 30분 후)"
- 건강 알림: "체온 38도 이상이 2일 연속입니다"
- 성장 마일스톤: "다음 마일스톤: 뒤집기 (평균 4-5개월)"

**근거**: 단순 기록앱 → 능동적 육아 도우미로 전환. 기존 PatternAnalysis + PercentileCalculator + MilestoneData 활용.
**작업량**: 중 (2-3일) | **파일**: DashboardView+Summary.swift, DashboardComponents.swift

---

### Tier 2: 중간 임팩트 + 기존 기능 확장

---

#### 5. 수면 분석 강화 (PatternReport+Sleep)

**현재**: 일별 수면 시간, 평균 지속 시간, 품질/방법 분포
**문제**: 수면 패턴 인사이트 부족. 수면 퇴행(Sleep Regression) 감지 없음.

**강화 방안**:
- 수면 퇴행 자동 감지 (4개월, 8개월, 12개월 전후 급격한 패턴 변화)
- 최적 취침 시간 추천 (최근 수면 데이터 기반)
- 낮잠 vs 밤잠 비율 트렌드
- 수면 품질 점수 (총 수면 시간 + 깨는 횟수 + 낮잠 수)

**작업량**: 중 (2일) | **파일**: PatternAnalysisService.swift, PatternReport+Sleep.swift, PatternModels.swift

---

#### 6. 일기 자동 요약 (DiaryViewModel)

**현재**: 텍스트 + 사진 + 기분. 검색/필터 기본만 존재.
**문제**: 일기가 쌓이면 돌아보기 어려움. 회고 기능 없음.

**강화 방안**:
- 월간 자동 요약: "이번 달 기분: 행복 60%, 피곤 25%..."
- "N개월 전 오늘" 회고 카드 (대시보드 또는 푸시)
- 기분 트렌드 차트 (월별 기분 분포 변화)
- 사진 갤러리 모드 (타임라인형 사진만 모아보기)

**작업량**: 중 (2-3일) | **파일**: DiaryViewModel.swift, DiaryView.swift

---

#### 7. 할일/루틴 자동 재생성 (TodoViewModel + RoutineViewModel)

**현재**: 반복 할일은 recurringInterval 필드만 있고 자동 재생성 안 됨. 루틴은 수동 리셋만.
**문제**: 매일 같은 할일을 수동 생성해야 함. 루틴도 매일 리셋 수동.

**강화 방안**:
- 반복 할일 완료 시 다음 할일 자동 생성 (daily/weekly/monthly)
- 루틴 자동 리셋 (매일 자정 미완료 항목 초기화)
- 할일 완료 스트릭 (연속 완료 일수 표시)
- 루틴 달성률 통계 (주간/월간)

**작업량**: 소 (1-2일) | **파일**: TodoViewModel.swift, RoutineViewModel.swift, TodoItem.swift

---

#### 8. 병원 방문 리포트 강화 (HospitalReportViewModel)

**현재**: 6단계 분석 파이프라인으로 PDF 생성. 기본 데이터 요약.
**문제**: 리포트에 성장 백분위, 수유/수면 패턴, 이상 징후 등이 통합되지 않음.

**강화 방안**:
- 소아과 방문 체크리스트 자동 생성 (예방접종 일정, 성장 이상, 최근 증상)
- 성장 백분위 차트 포함 (의사에게 보여주기용)
- 최근 2주 활동 요약 포함 (수유 패턴, 수면 패턴, 체온 추이)
- PDF 공유 버튼 (AirDrop, 메시지, 이메일)

**작업량**: 중 (2-3일) | **파일**: HospitalReportViewModel.swift, PDFReportService.swift, AnalysisEngine.swift

---

### Tier 3: 보통 임팩트 + 새 기능에 가까움

---

#### 9. 알레르기 추적 강화 (HealthViewModel)

**현재**: 알레르겐, 심각도, 메모만 기록.
**문제**: 이유식 도입 시기에 식품별 반응 추적이 핵심인데 통합되지 않음.

**강화 방안**:
- 이유식 기록(SolidFoodSection)과 알레르기 기록 자동 연동
- "반응: 알레르기" 기록 시 AllergyRecord 자동 생성 제안
- 식품별 반응 히스토리 (타임라인: 첫 시도 → 재시도 → 안전 확인)
- 안전 식품 / 주의 식품 / 금지 식품 분류 대시보드

**작업량**: 중 (2-3일) | **파일**: HealthViewModel.swift, SolidFoodSection.swift, AllergyListView.swift

---

#### 10. 예방접종 알림 강화 (HealthView + VaccinationListView)

**현재**: 접종 일정, 완료 체크, 기본 알림
**문제**: 다음 접종까지 D-day 카운트다운 없음. 일정 놓치기 쉬움.

**강화 방안**:
- 대시보드에 "다음 접종: BCG (D-7)" 카드 표시
- 접종 D-14, D-7, D-1 단계별 푸시 알림
- 접종 후 부작용 기록 기능 (발열, 부종, 시간 경과)
- 접종 완료율 배지/프로그레스 바

**작업량**: 소 (1-2일) | **파일**: HealthViewModel.swift, VaccinationListView.swift, NotificationService.swift, DashboardView+Summary.swift

---

#### 11. 제품/육아용품 스마트 추천 (ProductViewModel)

**현재**: 제품 등록, 구매 기록, 재구매 예측, 카탈로그 검색
**문제**: 추천이 수동. 월령 기반 필요 용품 자동 추천 없음.

**강화 방안**:
- 월령 기반 자동 추천 ("6개월: 이유식 그릇, 실리콘 빕 필요")
- 소모품 재구매 알림 강화 (기저귀/분유 소진 예측)
- 쿠팡 연동 딥링크로 바로 구매 (CoupangAffiliateService 활용)
- 다른 부모들의 인기 용품 (카탈로그 기반)

**작업량**: 중 (2-3일) | **파일**: ProductViewModel.swift, CatalogService.swift, CoupangAffiliateService.swift

---

#### 12. 위젯 강화 (BabyCareWidget)

**현재**: 기본 위젯 + Live Activity (타이머)
**문제**: 위젯에 표시되는 정보가 제한적.

**강화 방안**:
- 다음 수유/낮잠 예상 시간 위젯
- 오늘 활동 요약 위젯 (수유 N회, 수면 N시간)
- 성장 백분위 위젯 (최근 측정값 + 백분위)
- Lock Screen 위젯 추가 (iOS 16+)

**작업량**: 중 (2-3일) | **파일**: BabyCareWidget/, WidgetDataStore.swift

---

## 비강화 대상 (현재 수준 적정)

| 기능 | 이유 |
|------|------|
| 인증/계정 | 기본 기능 충분 |
| 캘린더 | 기본 일정 표시 충분 |
| 사운드 플레이어 | 부가 기능, 강화 우선순위 낮음 |
| 관리자 대시보드 | 내부 도구, 사용자 미노출 |
| 광고/애드몹 | 수익화 인프라, 기능 강화 대상 아님 |
| 오프라인/동기화 | 이미 잘 구현됨 (RetryHelper + OfflineQueue) |
| 가족 공유 | 기본 기능 충분 (초대 코드 + 공유 접근) |

---

## 추천 실행 순서

| 순서 | 기능 | Tier | 이유 |
|------|------|------|------|
| **1** | 수유 예측 고도화 | T1 | 가장 높은 ROI. 데이터 있고 서비스 1개만 수정 |
| **2** | 주간 인사이트 리포트 | T1 | 리텐션 핵심. 패턴분석 이미 완비 |
| **3** | 대시보드 인사이트 카드 | T1 | 1+2와 시너지. 앱 열 때마다 가치 전달 |
| **4** | 성장 차트 강화 | T1 | 시각적 임팩트 큼. Apple Charts로 구현 |
| **5** | 수면 분석 + 퇴행 감지 | T2 | 부모 불안 해소. 패턴분석 확장 |
| **6** | 예방접종 알림 강화 | T3 | 간단한 작업으로 큰 UX 개선 |
| **7** | 할일/루틴 자동화 | T2 | 소규모 작업으로 일상 편의성 ↑ |
| **8** | 일기 자동 요약 | T2 | 감성적 가치. 장기 리텐션 |
| **9** | 알레르기 추적 강화 | T3 | 이유식 시기 부모에게 필수 |
| **10** | 병원 리포트 강화 | T2 | 소아과 방문 시 실용적 가치 |
| **11** | 제품 추천 | T3 | 수익화 연계 가능 |
| **12** | 위젯 강화 | T3 | 홈화면 노출 증가 |
