import SwiftUI
import UIKit

/// 여행 공간 모양 — Dev 시안(캔버스 Dev 페이지 · *.dc.html)의 숫자를 그대로 가져온다(눈금을 새로 정하지 않는다).
/// 밝은 화면 = 시안 값 · 어두운 화면 = iOS 기본 색(시안에 어두운 판이 없다).
/// 글자체: 시안은 Pretendard, 앱은 시스템 글꼴(베이비케어 전체와 같게) — 크기·굵기·색·줄 간격은 시안 그대로.
enum TravelStyle {
    // MARK: 색 — 시안 값(밝게) / iOS 기본(어둡게)
    static let page = dynamic(0xFFFFFF, dark: .systemBackground)
    static let ink = dynamic(0x191F2B, dark: .label)
    static let body = dynamic(0x333D4B, dark: .label)
    static let sub = dynamic(0x6B7684, dark: .secondaryLabel)
    static let line = dynamic(0xEEF0F3, dark: .separator)
    static let band = dynamic(0xF2F4F6, dark: .secondarySystemBackground)
    static let box = dynamic(0xF7F8FA, dark: .secondarySystemBackground)
    static let chip = dynamic(0xF2F4F6, dark: .tertiarySystemFill)
    static let cardBorder = dynamic(0xE6E8EC, dark: .separator)
    /// 표 맨 위 선(시안 아이 프로필 #DDE1E6).
    static let tableTop = dynamic(0xDDE1E6, dark: .separator)
    static let pillBorder = dynamic(0xD5D9DF, dark: .separator)
    static let checkBorder = dynamic(0xC9CED6, dark: .tertiaryLabel)
    static let red = dynamic(0xE52528, dark: .systemRed)
    /// 빨간 알림 바탕(시안 #FFF4F4) · 「담당 없음」 칩 바탕(#FFF0F0).
    static let redSoft = dynamic(0xFFF4F4, dark: UIColor.systemRed.withAlphaComponent(0.18))
    static let redChip = dynamic(0xFFF0F0, dark: UIColor.systemRed.withAlphaComponent(0.18))
    /// 하루 일정 — 아이 상자 #EEF1F5 · 아이 점 테두리 #9AA1AB.
    static let babyBox = dynamic(0xEEF1F5, dark: .tertiarySystemFill)
    static let babyDot = dynamic(0x9AA1AB, dark: .tertiaryLabel)
    /// 시안 {{primary}} — 보드 렌더 값 #346AFF.
    static let primary = dynamic(0x346AFF, dark: .systemBlue)
    /// 아래 바 고른 칸 알약(PO 참고 화면 실측 #F1F1F2).
    static let tabPill = dynamic(0xF1F1F2, dark: .tertiarySystemFill)
    /// 여행 기간 달력 — 시작·끝 사이 띠(시안 Trip-Edit #EAF0FF).
    static let rangeBand = dynamic(0xEAF0FF, dark: UIColor.systemBlue.withAlphaComponent(0.22))
    /// 칩 ✕ · 비어 있는 자리 글자(시안 #8B95A1).
    static let faint = dynamic(0x8B95A1, dark: .tertiaryLabel)
    /// 검색 칸 지우기 ✕(시안 Search-Move #B0B8C1).
    static let clearMark = dynamic(0xB0B8C1, dark: .tertiaryLabel)
    /// 홈 다음 일정의 아이 칩(시안 Main 「낮잠 14:10과 탑승이 겹쳐요」 — 글 #A15C00 · 바탕 #FFF4E5).
    static let amber = dynamic(0xA15C00, dark: .systemOrange)
    static let amberSoft = dynamic(0xFFF4E5, dark: UIColor.systemOrange.withAlphaComponent(0.18))

    // MARK: 칸
    static let gutter: CGFloat = 16
    static let bandHeight: CGFloat = 8

    private static func dynamic(_ hex: UInt32, dark: UIColor) -> Color {
        let light = UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - 글자 — 시안 px 를 기본 크기로, 글자 크기 설정을 따라 커진다

private struct TravelFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let tracking: CGFloat

    init(size: CGFloat, weight: Font.Weight, tracking: CGFloat, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.tracking = tracking
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .tracking(size * tracking)
    }
}

extension View {
    /// 시안 글자 — size(px) · weight · letter-spacing(em). 기본 글자 간격은 시안 바탕값 -0.01em.
    func travelFont(_ size: CGFloat, _ weight: Font.Weight = .regular, tracking: CGFloat = -0.01) -> some View {
        let style: Font.TextStyle = size >= 18 ? .title3 : (size >= 15 ? .body : (size >= 13 ? .subheadline : .caption))
        return modifier(TravelFont(size: size, weight: weight, tracking: tracking, relativeTo: style))
    }

    /// 시안 줄 간격(line-height 배수) — 시스템 글꼴 기본(약 1.2배) 위에 더한다.
    func travelLineHeight(_ multiple: CGFloat, size: CGFloat) -> some View {
        lineSpacing(max(0, (multiple - 1.2) * size))
    }

    /// 목록 한 줄 — 좌우 16 · 시스템 구분선 없음(시안은 줄 위에 1px 선을 직접 긋는다) · 흰 바탕.
    func travelRow(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: TravelStyle.gutter, bottom: bottom, trailing: TravelStyle.gutter))
            .listRowSeparator(.hidden)
            .listRowBackground(TravelStyle.page)
    }
}

// MARK: - 목록 틀

/// 시안 화면 바탕 — 흰 바탕 납작 목록(회색 둥근 묶음 아님). 줄 사이 8px 회색 띠로 칸을 나눈다.
struct TravelList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        List {
            content()
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .background(TravelStyle.page)
    }
}

/// 칸 나눔 — 높이 8 · #F2F4F6 · 화면 폭 끝까지.
struct TravelBandRow: View {
    var body: some View {
        TravelStyle.band
            .frame(height: TravelStyle.bandHeight)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(TravelStyle.band)
    }
}

/// 줄 위 1px 선(시안 border-top: 1px solid #EEF0F3).
struct TravelHairline: View {
    var body: some View {
        TravelStyle.line.frame(height: 1)
    }
}

/// 칸 화면 머리(시안 일정 · 예약 · 준비) — 22 굵게(-0.02 · 줄 1.3) + 13 회색 한 줄 · 여백 16 16 10 · 사이 4.
struct TravelScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .travelFont(22, .bold, tracking: -0.02)
                .travelLineHeight(1.3, size: 22)
                .foregroundStyle(TravelStyle.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TravelStyle.gutter)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(TravelStyle.page)
    }
}

/// 칸 머리 — 16 굵게(600) · 오른쪽 13 회색(누르면 「›」).
struct TravelSectionHeader: View {
    let title: String
    var trailing: String?
    var minHeight: CGFloat = 44
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .travelFont(16, .semibold)
                .foregroundStyle(TravelStyle.ink)
            Spacer(minLength: 8)
            if let trailing {
                if let action {
                    Button(action: action) {
                        HStack(spacing: 2) {
                            Text(trailing)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                } else {
                    Text(trailing)
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                        .monospacedDigit()
                }
            }
        }
        .frame(minHeight: minHeight)
    }
}

/// 작은 네모 칩 — 담당 · 상태(시안 height 22 · 12px · 4 둥근 모서리). small = 할 일 줄 안(height 19).
struct TravelChip: View {
    enum Tone { case neutral, red, redStrong }

    let text: String
    var tone: Tone = .neutral
    var small = false

    var body: some View {
        Text(text)
            .travelFont(12, tone == .redStrong ? .semibold : .regular)
            .foregroundStyle(tone == .neutral ? TravelStyle.body : TravelStyle.red)
            .lineLimit(1)
            .padding(.horizontal, small ? 6 : 7)
            .frame(minHeight: small ? 19 : 22)
            .background(RoundedRectangle(cornerRadius: 4).fill(background))
            .fixedSize()
    }

    private var background: Color {
        switch tone {
        case .neutral: return TravelStyle.chip
        case .red: return TravelStyle.redChip
        case .redStrong: return TravelStyle.redSoft
        }
    }
}

/// 둥근 체크 — 22 · 테두리 1.5 #C9CED6 · 켜지면 바탕 primary + 흰 체크.
struct TravelCheckCircle: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isOn ? TravelStyle.primary : TravelStyle.page)
            Circle()
                .strokeBorder(isOn ? TravelStyle.primary : TravelStyle.checkBorder, lineWidth: 1.5)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// 회색 테두리 버튼(시안 「이 길을 구글지도에서 열기」) — 높이 44 · 테두리 #D5D9DF · 14 #333D4B.
struct TravelOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .travelFont(14)
            .foregroundStyle(TravelStyle.body)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.page))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(TravelStyle.pillBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 세로 점선(시안 정류장 사이 이동 — #C9CED6 2px 점선).
struct TravelDashedRail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// 파란 글자 고리(시안 「입국장 1층 수유실 보기 ›」) — 13 primary · 높이 32.
struct TravelLinkLabel: View {
    let text: String
    var systemImage = "chevron.right"

    var body: some View {
        HStack(spacing: 1) {
            Text(text)
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
        }
        .travelFont(13)
        .foregroundStyle(TravelStyle.primary)
        .frame(minHeight: 32)
    }
}

/// 위쪽 밑줄 칸 바꾸기(시안 준비 메뉴 — 할 일 · 규칙 · 높이 48 · 고른 칸 아래 2px 검은 줄 · 15).
struct TravelUnderlineTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let selected = item == selection
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .travelFont(15, selected ? .semibold : .regular)
                        .foregroundStyle(selected ? TravelStyle.ink : TravelStyle.sub)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(alignment: .bottom) {
                            (selected ? TravelStyle.ink : Color.clear).frame(height: 2)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background(alignment: .bottom) { TravelHairline() }
        .background(TravelStyle.page)
    }
}

/// 담당 칩(누르면 고르기) — 시안 칩 모양 · 담당이 없으면 빨간 「담당 없음」.
struct TravelAssigneeChipMenu: View {
    let state: TripTaskState?
    var small = false
    let onAssign: (TripAssignee) -> Void

    var body: some View {
        Menu {
            ForEach(TripAssignee.selectable, id: \.self) { a in
                Button {
                    onAssign(a)
                } label: {
                    if state?.assignee == a {
                        Label(a.label, systemImage: "checkmark")
                    } else {
                        Text(a.label)
                    }
                }
            }
        } label: {
            TravelChip(text: TravelAssigneeChipText.text(state?.assignee),
                       tone: TravelAssigneeChipText.isMissing(state?.assignee) ? .red : .neutral, small: small)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("담당 바꾸기, 지금 \(TravelAssigneeChipText.text(state?.assignee))")
    }
}
