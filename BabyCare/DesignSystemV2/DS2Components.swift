import SwiftUI

// MARK: - DS2Card

/// 통일 카드 컴포넌트. `tint`에 활동/시맨틱 색 전달 시 12% opacity 배경.
struct DS2Card<Content: View>: View {
    let tint: Color?
    let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS2.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous)
                    .fill(tint?.opacity(0.12) ?? DS2.Color.surfaceSecondary)
            )
    }
}

// MARK: - DS2Button

enum DS2ButtonStyle {
    case primary
    case secondary
    case destructive
    case ghost
}

struct DS2Button: View {
    let title: String
    let icon: String?
    let style: DS2ButtonStyle
    let action: () -> Void

    init(_ title: String, icon: String? = nil, style: DS2ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(DS2.Font.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, DS2.Spacing.lg)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            DS2.Color.accent
        case .secondary:
            DS2.Color.surfaceSecondary
        case .destructive:
            DS2.Color.danger
        case .ghost:
            Color.clear
        }
    }

    private var foreground: Color {
        switch style {
        case .primary, .destructive:
            return DS2.Color.textOnAccent
        case .secondary, .ghost:
            return DS2.Color.textPrimary
        }
    }
}

// MARK: - DS2Section

struct DS2Section<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content

    init(_ title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.md) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    if let title = title {
                        Text(title).font(DS2.Font.title3)
                    }
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DS2.Font.subheadline)
                            .foregroundStyle(DS2.Color.textSecondary)
                    }
                }
            }
            content
        }
    }
}

// MARK: - DS2EmptyState

struct DS2EmptyState: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DS2.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(DS2.Color.textSecondary)
            VStack(spacing: DS2.Spacing.sm) {
                Text(title).font(DS2.Font.headline)
                if let message = message {
                    Text(message)
                        .font(DS2.Font.subheadline)
                        .foregroundStyle(DS2.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let actionTitle = actionTitle, let action = action {
                DS2Button(actionTitle, style: .secondary, action: action)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS2.Spacing.xxl)
    }
}

// MARK: - DS2ListRow

struct DS2ListRow<Trailing: View>: View {
    let icon: String?
    let iconTint: Color
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        icon: String? = nil,
        iconTint: Color = DS2.Color.accent,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DS2.Spacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconTint)
                    .frame(width: 32, height: 32)
                    .background(
                        iconTint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS2.Font.body)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
            }
            Spacer(minLength: DS2.Spacing.sm)
            trailing
        }
        .padding(.vertical, DS2.Spacing.sm)
        .padding(.horizontal, DS2.Spacing.lg)
        .frame(minHeight: 56)
        .background(
            DS2.Color.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous)
        )
    }
}

extension DS2ListRow where Trailing == EmptyView {
    init(
        icon: String? = nil,
        iconTint: Color = DS2.Color.accent,
        title: String,
        subtitle: String? = nil
    ) {
        self.init(icon: icon, iconTint: iconTint, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}
