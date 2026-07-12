# 수유 용어 정리 + 유축 재고 (완성형) — 설계 문서

- **날짜**: 2026-07-12
- **브랜치**: `feat/unified-recording`
- **동기**: PO QA — "유축은 저장, 소비는 분유에 들어가 있어 맥락이 안 맞음" + "라벨 짧게(모유·분유·유축)". 라이브 서비스라 **완성형**(유통기한·재고 연동 포함, v1 컷 금지).
- **안전**: 유통기한·보관시간은 **의학 정보** → 초안 + 면책, 산부인과/소아과 감수 전 단정 금지(safety.md). 감수 = PO/외부 게이트.

---

## 1. 용어 (짧게) + 수유 체계

**먹이기(섭취) 타일** — displayName 짧게:
| 타일 | 내부 (enum·content) | 재고 |
|---|---|---|
| **모유** | feedingBreast | — |
| **분유** | feedingBottle · content=formula | — |
| **유축** | feedingBottle · content=breastMilk | **차감** |
| **이유식** | feedingSolid | — |
| **간식** | feedingSnack | — |

**짜기(생산)**: **짜기** = feedingPumping → **재고 적립**(배치 생성). ("유축"은 먹이기 타일이 가져감 → 생산은 "짜기"로 분리, 라벨 충돌 제거)

- **마이그레이션 0**: 신규 enum 없음. 기존 feedingBottle+breastMilk = 유축(먹이기)로 자동 취급, feedingPumping = 짜기로. displayName만 조정.
- displayName: feedingPumping "유축"→**"짜기"**. feedingBottle content-aware: formula→"분유", breastMilk→**"유축"**.
- 타일 표현: 그리드/런처 타일에 **content 프리셋** 부여(분유=formula, 유축=breastMilk). RecordEntryRule은 type 기준(둘 다 feedingBottle=detail).

---

## 2. 유축 재고 (Pumped Milk Inventory) — 완성형

### 2.1 모델 (배치 기반, 신규 컬렉션 없이 Activity 확장)
- **배치 = feedingPumping(짜기) 1건** + 신규 optional 필드:
  - `pumpStorage: PumpStorage?` (실온/냉장/냉동) — 유통기한 산정 기준.
  - `pumpDiscarded: Bool?` — 폐기 표시.
- **유통기한** = `pumpedAt(startTime) + PumpStorage.shelfLife` (의학 초안):
  - 실온(~25°C): 4시간 · 냉장(~4°C): 4일 · 냉동: 6개월 · 해동 후 냉장: 24시간. **초안·면책·감수 전.**
- **소비** = 유축 먹이기(feedingBottle+breastMilk) 1건.
- **재고 잔량** = Σ(만료·폐기 안 된 배치 남은 양). FIFO: 소비는 **가장 오래된 미만료 배치부터** 차감(버림 최소화).

### 2.2 순수 로직 (`PumpedMilkInventory`)
```
struct PumpBatch { id, amount, pumpedAt, storage, expiresAt, discarded }
struct InventoryState { totalRemaining: Double, batches: [BatchStatus], soonestExpiry: Date? }
enum PumpedMilkInventory {
  static func expiry(pumpedAt:, storage:) -> Date                 // 의학 초안 상수
  static func compute(pumpEvents:[Activity], feedEvents:[Activity], now:) -> InventoryState
      // FIFO 배분: feed 총량을 오래된 미만료 배치부터 차감 → 배치별 remaining, 총잔량, 임박만료
}
```
- 만료 배치는 잔량서 제외 + "만료" 상태로 표기(폐기 유도). 음수 방지(먹인 양>재고 시 잔량 0 + "추적 전 재고" 안내).

### 2.3 UX
- **대시보드 유축 재고 카드**: "냉장고 모유 약 350mL · 냉장 120mL 내일 만료". 탭 → 재고 화면.
- **짜기 시트**(feedingPumping): 짜낸 양 + **보관(실온/냉장/냉동)** → 배치 생성, 유통기한 자동 표시.
- **유축 시트**(feedingBottle+breastMilk): 현재 잔량 표시 + 먹인 양 → FIFO 차감. 부족 시 경고(저장은 허용).
- **재고 화면**(PumpedMilkStockView): 배치 목록(양·짜낸시각·보관·유통기한·상태[신선/임박/만료]) + **폐기** 스와이프 + 총잔량.
- **유통기한 알림**: 임박·만료 배치 로컬 알림(설정 토글, 기본 ON). 카피 의료 압박 없이.

### 2.4 데이터/소급
- 기존 feedingPumping 레코드 = storage nil → 기본 보관(냉장?) 가정 or "미지정" 표기. 소급 반영하되 유통기한 불명은 경고 없이 잔량만.
- 기존 feedingBottle+breastMilk = 소비로 소급 차감.
- 완벽 추적 아니면 어긋남 → **재고 직접 조정**(현재 잔량 = N 설정 = 조정 배치 1건 생성) 제공.

---

## 3. 제약·불변
- Firestore 마이그레이션 0(신규 필드 optional·Codable). 신규 컬렉션 없음(Activity 확장) → Narrow Protocol 불필요. enum raw value 불변(신규 PumpStorage enum은 신규·raw 영구계약).
- 의학 텍스트(유통기한·보관) = 초안 + 면책, 감수 전 단정 금지. `context/` 문서로 근거 분리, PO/의료 감수 H-item.
- arch R1–4=0 · print 금지 · TDD(순수 Inventory 우선).
- GA4: 짜기/유축/폐기 이벤트 계측(양 raw 금지, bucket).

## 4. 단계 (각 verify green)
- **P1(빌드102·완료중)**: 용어 무관 QA fix(모유수유·이유식 원탭·시간버튼·토스트).
- **P2 용어/타일**: displayName 짧게 + 분유/유축 타일 분리(content 프리셋) + 짜기 라벨. UI만, 재고 전.
- **P3 재고 순수로직**: `PumpStorage`·`PumpBatch`·`PumpedMilkInventory`(expiry·FIFO·compute) TDD.
- **P4 짜기/유축 시트 + 재고 카드**: 보관 입력·잔량 표시·FIFO 차감·대시보드 카드.
- **P5 재고 화면 + 폐기 + 알림 + 조정**: PumpedMilkStockView·유통기한 알림·직접 조정.

## 5. 미해결 게이트 (PO/의료)
- 유통기한 숫자 확정(의료 감수) — 그전까진 초안+면책으로 구현·표기.
- 기존 데이터 소급 vs 도입시점 시작 — 기본 소급(조정 제공).
