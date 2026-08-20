import SwiftUI

// MARK: - StoolDetailSection

struct StoolDetailSection: View {
    @Environment(ActivityViewModel.self) var activityVM
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // 대변 색상
            VStack(alignment: .leading, spacing: 8) {
                Label("대변 색상", systemImage: "paintpalette.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Activity.StoolColor.allCases, id: \.self) { color in
                        Button {
                            activityVM.stoolColor = activityVM.stoolColor == color ? nil : color
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: color.colorHex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                activityVM.stoolColor == color ? Color.primary : .clear,
                                                lineWidth: 2.5
                                            )
                                            .padding(-2)
                                    )
                                    .overlay {
                                        if activityVM.stoolColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(color == .white ? .black : .white)
                                        }
                                    }
                                Text(color.displayName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // 의료 주의 경고
                if let color = activityVM.stoolColor, color.needsAttention {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(color == .red
                             ? "붉은색 대변은 혈변일 수 있습니다. 소아과 상담을 권장합니다."
                             : "흰색 대변은 담도 이상의 신호일 수 있습니다. 소아과 상담을 권장합니다.")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Divider()

            // 대변 농도
            VStack(alignment: .leading, spacing: 8) {
                Label("대변 농도", systemImage: "water.waves")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.StoolConsistency.allCases, id: \.self) { consistency in
                        Button {
                            activityVM.stoolConsistency = activityVM.stoolConsistency == consistency ? nil : consistency
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: consistency.icon)
                                    .font(.body)
                                Text(consistency.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                activityVM.stoolConsistency == consistency
                                    ? accentColor : accentColor.opacity(0.08)
                            )
                            .foregroundStyle(
                                activityVM.stoolConsistency == consistency ? .white : accentColor
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Divider()

            // 발진 체크
            HStack {
                Label("발진 여부", systemImage: "bandage.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { activityVM.hasRash },
                    set: { activityVM.hasRash = $0 }
                ))
                .labelsHidden()
                .tint(.red)
            }

            if activityVM.hasRash {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("발진이 지속되면 소아과 상담을 권장합니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(duration: 0.3), value: activityVM.stoolColor)
        .animation(.spring(duration: 0.3), value: activityVM.hasRash)
    }
}
