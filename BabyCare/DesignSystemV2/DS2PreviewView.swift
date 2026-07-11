import SwiftUI

/// DS2 디자인 시스템 Showcase.
/// Settings → 실험실 진입점에서 노출 (#if DEBUG — 출시 빌드 제외, Track A 결정).
struct DS2PreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS2.Spacing.xl) {
                introSection
                colorSection
                spacingSection
                radiusSection
                fontSection
                shadowSection
                componentSection
            }
            .padding(DS2.Spacing.lg)
        }
        .background(DS2.Color.surfacePrimary.ignoresSafeArea())
        .navigationTitle("DS V2 미리보기")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introSection: some View {
        DS2Section("디자인 시스템 V2", subtitle: "현재 톤 정제 — 폐기 가능 네임스페이스 (DS2.*)") {
            DS2Card(tint: DS2.Color.tintMint) {
                VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                    Text("Spacing 4·8·12·16·24·32 · Radius 12·16·24 · Font 10단계")
                        .font(DS2.Font.callout)
                    Text("FeatureFlag.designSystemV2Preview = true 로 노출")
                        .font(DS2.Font.caption2)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Color
    private var colorSection: some View {
        DS2Section("Color") {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                label("Surface / Brand")
                colorRow([
                    ("surfacePrimary", DS2.Color.surfacePrimary),
                    ("surfaceSecondary", DS2.Color.surfaceSecondary),
                    ("accent", DS2.Color.accent),
                ])
                label("Activity")
                colorRow([
                    ("feeding", DS2.Color.feeding),
                    ("sleep", DS2.Color.sleep),
                    ("diaper", DS2.Color.diaper),
                    ("solid", DS2.Color.solid),
                ])
                colorRow([
                    ("bath", DS2.Color.bath),
                    ("temperature", DS2.Color.temperature),
                    ("medication", DS2.Color.medication),
                ])
                label("Semantic")
                colorRow([
                    ("success", DS2.Color.success),
                    ("warning", DS2.Color.warning),
                    ("danger", DS2.Color.danger),
                    ("info", DS2.Color.info),
                ])
                label("Tint (pastel)")
                colorRow([
                    ("pink", DS2.Color.tintPink),
                    ("blue", DS2.Color.tintBlue),
                    ("mint", DS2.Color.tintMint),
                ])
                colorRow([
                    ("yellow", DS2.Color.tintYellow),
                    ("purple", DS2.Color.tintPurple),
                    ("orange", DS2.Color.tintOrange),
                ])
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(DS2.Font.caption)
            .foregroundStyle(DS2.Color.textSecondary)
            .padding(.top, DS2.Spacing.sm)
    }

    private func colorRow(_ items: [(String, Color)]) -> some View {
        HStack(spacing: DS2.Spacing.sm) {
            ForEach(items, id: \.0) { name, color in
                VStack(spacing: DS2.Spacing.xs) {
                    RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                        .fill(color)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                                .stroke(.quaternary, lineWidth: 0.5)
                        )
                    Text(name).font(DS2.Font.caption2)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Spacing
    private var spacingSection: some View {
        DS2Section("Spacing (8pt grid)") {
            VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                spacingRow("xs", 4)
                spacingRow("sm", 8)
                spacingRow("md", 12)
                spacingRow("lg", 16)
                spacingRow("xl", 24)
                spacingRow("xxl", 32)
            }
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: DS2.Spacing.md) {
            Text("\(name) (\(Int(value))pt)")
                .font(DS2.Font.caption)
                .frame(width: 96, alignment: .leading)
            Rectangle()
                .fill(DS2.Color.accent)
                .frame(width: value, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
    }

    // MARK: - Radius
    private var radiusSection: some View {
        DS2Section("Radius") {
            HStack(spacing: DS2.Spacing.md) {
                radiusBox("sm 12", 12)
                radiusBox("md 16", 16)
                radiusBox("lg 24", 24)
            }
        }
    }

    private func radiusBox(_ name: String, _ radius: CGFloat) -> some View {
        VStack(spacing: DS2.Spacing.xs) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DS2.Color.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(DS2.Color.accent, lineWidth: 1.5)
                )
                .frame(height: 64)
            Text(name).font(DS2.Font.caption2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Font
    private var fontSection: some View {
        DS2Section("Font") {
            VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                fontRow("largeTitle", DS2.Font.largeTitle)
                fontRow("title", DS2.Font.title)
                fontRow("title2", DS2.Font.title2)
                fontRow("title3", DS2.Font.title3)
                fontRow("headline", DS2.Font.headline)
                fontRow("body", DS2.Font.body)
                fontRow("callout", DS2.Font.callout)
                fontRow("subheadline", DS2.Font.subheadline)
                fontRow("caption", DS2.Font.caption)
                fontRow("caption2", DS2.Font.caption2)
            }
        }
    }

    private func fontRow(_ name: String, _ font: Font) -> some View {
        HStack(spacing: DS2.Spacing.md) {
            Text(name)
                .font(DS2.Font.caption2)
                .foregroundStyle(DS2.Color.textSecondary)
                .frame(width: 110, alignment: .leading)
            Text("아기 케어 한글 가독성")
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Shadow
    private var shadowSection: some View {
        DS2Section("Shadow") {
            HStack(spacing: DS2.Spacing.md) {
                shadowBox("sm", .sm)
                shadowBox("md", .md)
                shadowBox("lg", .lg)
            }
            .padding(.vertical, DS2.Spacing.md)
        }
    }

    private func shadowBox(_ name: String, _ shadow: DS2.Shadow) -> some View {
        VStack(spacing: DS2.Spacing.xs) {
            RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous)
                .fill(DS2.Color.surfaceSecondary)
                .frame(height: 64)
                .ds2Shadow(shadow)
            Text(name).font(DS2.Font.caption2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Component
    private var componentSection: some View {
        DS2Section("Component") {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                DS2Card {
                    VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                        Text("DS2Card (default)").font(DS2.Font.headline)
                        Text("기본 surface 카드. radius 16, padding 16.")
                            .font(DS2.Font.subheadline)
                            .foregroundStyle(DS2.Color.textSecondary)
                    }
                }
                DS2Card(tint: DS2.Color.feeding) {
                    VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                        Text("DS2Card (tint = feeding)").font(DS2.Font.headline)
                        Text("활동 색 12% opacity tint.")
                            .font(DS2.Font.subheadline)
                            .foregroundStyle(DS2.Color.textSecondary)
                    }
                }

                VStack(spacing: DS2.Spacing.sm) {
                    DS2Button("Primary", icon: "checkmark", style: .primary, action: {})
                    DS2Button("Secondary", icon: "square.and.arrow.down", style: .secondary, action: {})
                    DS2Button("Destructive", icon: "trash", style: .destructive, action: {})
                    DS2Button("Ghost", style: .ghost, action: {})
                }

                VStack(spacing: DS2.Spacing.sm) {
                    DS2ListRow(
                        icon: "drop.fill",
                        iconTint: DS2.Color.feeding,
                        title: "수유",
                        subtitle: "5시간 전 · 60ml"
                    ) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(DS2.Color.textSecondary)
                    }
                    DS2ListRow(
                        icon: "moon.fill",
                        iconTint: DS2.Color.sleep,
                        title: "수면",
                        subtitle: "어제 22:00 ~ 06:00"
                    )
                }

                DS2EmptyState(
                    icon: "tray",
                    title: "기록 없음",
                    message: "오늘의 활동을 시작해 보세요.",
                    actionTitle: "수유 기록 추가",
                    action: {}
                )
            }
        }
    }
}

#Preview("Light") {
    NavigationStack { DS2PreviewView() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack { DS2PreviewView() }
        .preferredColorScheme(.dark)
}
