import SwiftUI

// MARK: - AuthFormField

struct AuthFormField<Content: View>: View {
    let label: String
    let icon: String
    var borderColor: Color = Color(.separator)
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Password Strength View

struct PasswordStrengthView: View {
    let password: String

    private var strength: PasswordStrength {
        if password.count < 6 { return .weak }
        let hasUpper = password.contains(where: \.isUppercase)
        let hasNumber = password.contains(where: \.isNumber)
        let hasSpecial = password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) })
        let score = [hasUpper, hasNumber, hasSpecial].filter { $0 }.count
        if password.count >= 12 && score >= 2 { return .strong }
        if password.count >= 8 && score >= 1 { return .medium }
        return .weak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < strength.filledBars ? strength.color : Color(.systemGray4))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: strength.filledBars)
                }
            }

            Text("비밀번호 강도: \(strength.label)")
                .font(.caption2)
                .foregroundStyle(strength.color)
        }
        .padding(.horizontal, 2)
    }

    private enum PasswordStrength {
        case weak, medium, strong

        var filledBars: Int {
            switch self {
            case .weak: return 1
            case .medium: return 2
            case .strong: return 3
            }
        }

        var color: Color {
            switch self {
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }

        var label: String {
            switch self {
            case .weak: return "약함"
            case .medium: return "보통"
            case .strong: return "강함"
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environment(AuthViewModel())
    }
}
