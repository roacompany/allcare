import SwiftUI

/// 여행 공간의 칸 — 아래 바 순서대로(캔버스 Version 84 · PO 11/6 「네 시안.」: 홈 · 일정 · 예약 · 준비).
/// rawValue 는 UI 테스트 식별자(travel.tab.<rawValue>)에 쓰인다.
enum TravelTab: String, Hashable, CaseIterable, Identifiable {
    case home, plan, bookings, prep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "홈"
        case .plan: return "일정"
        case .bookings: return "예약"
        case .prep: return "준비"
        }
    }

    /// 시안 아이콘 — 집 · 달력 · 표 · 체크 목록. 고른 칸은 같은 기호를 굵게(시안 선 굵기 1.7 → 2).
    var icon: String {
        switch self {
        case .home: return "house"
        case .plan: return "calendar"
        case .bookings: return "ticket"
        case .prep: return "checklist"
        }
    }
}

/// 여행 공간 아래 바(PO 2026-11-05 참고 화면) — 왼쪽 동그란 「←」(베이비케어로) + 떠 있는 둥근 바(홈·일정·예약·준비).
/// 숫자는 참고 화면 원본(1184px 폭 = 402pt)을 재서 옮겼다: 동그라미·바 높이 61 · 사이 8 · 좌우 20 · 화면 아래에서 22 ·
/// 고른 칸 = 회색 알약(#F1F1F2 · 위아래 5) · 아이콘 21 · 글자 12. 고른 칸은 굵은 아이콘·글자 + 알약, 나머지도 진한 글자.
struct TravelBottomBar: View {
    @Binding var tab: TravelTab
    let onBack: () -> Void

    static let height: CGFloat = 61
    static let gap: CGFloat = 8
    static let side: CGFloat = 20
    /// 화면 맨 아래에서 바 아래까지(홈 표시줄 위로 겹쳐 뜬다).
    static let screenBottom: CGFloat = 22

    /// 내용이 바에 가리지 않게 — 화면 아래에서 바 위까지 + 8, 이미 있는 아래 안전 영역만큼은 뺀다.
    static func contentInset(safeBottom: CGFloat) -> CGFloat {
        max(0, screenBottom + height + 8 - safeBottom)
    }

    var body: some View {
        HStack(spacing: Self.gap) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(TravelStyle.ink)
                    .frame(width: Self.height, height: Self.height)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .travelGlass(in: Circle())
            .accessibilityLabel("베이비케어로 돌아가기")
            .accessibilityIdentifier("travel.back")

            HStack(spacing: 0) {
                ForEach(TravelTab.allCases) { item in
                    tabButton(item)
                }
            }
            .padding(5)
            .frame(height: Self.height)
            .travelGlass(in: Capsule())
        }
        .padding(.horizontal, Self.side)
        .sensoryFeedback(.selection, trigger: tab)
    }

    private func tabButton(_ item: TravelTab) -> some View {
        let selected = item == tab
        return Button {
            tab = item
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 21, weight: selected ? .medium : .regular))
                    .frame(height: 25)
                Text(item.title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(TravelStyle.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected { Capsule().fill(TravelStyle.tabPill) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("travel.tab.\(item.id)")
    }
}

extension View {
    /// 떠 있는 바 바탕 — iOS 26 부터 유리, 그 아래는 흰 반투명 + 옅은 테두리·그림자.
    @ViewBuilder
    func travelGlass<S: InsettableShape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(TravelStyle.cardBorder, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 3)
        }
    }
}
