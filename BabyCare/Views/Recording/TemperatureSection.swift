import SwiftUI

import SwiftUI

// MARK: - TemperatureSection

struct TemperatureSection: View {
    @Environment(ActivityViewModel.self) var activityVM
    let accentColor: Color

    // Fever thresholds
    var temperatureDouble: Double { Double(activityVM.temperatureInput) ?? 0 }
    var feverStatus: (String, Color)? {
        guard temperatureDouble > 0 else { return nil }
        if temperatureDouble >= 38.5 { return ("고열", .red) }
        if temperatureDouble >= 37.5 { return ("미열", AppColors.coralColor) }
        return ("정상", .green)
    }

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 12) {
            Label("체온 입력", systemImage: "thermometer.medium")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("36.5", text: $vm.temperatureInput)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("°C")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }

            if let (label, color) = feverStatus {
                HStack {
                    Spacer()
                    Label(label, systemImage: "circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(color)
                }
                .transition(.opacity)
            }

            if let warning = activityVM.temperatureWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    Text(warning)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(temperatureDouble >= 40.0 ? Color.red : AppColors.coralColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Quick-entry buttons
            HStack(spacing: 8) {
                ForEach(["36.5", "37.0", "37.5", "38.0", "38.5"], id: \.self) { temp in
                    Button(temp) {
                        activityVM.temperatureInput = temp
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        activityVM.temperatureInput == temp
                            ? accentColor
                            : accentColor.opacity(0.1)
                    )
                    .foregroundStyle(
                        activityVM.temperatureInput == temp ? .white : accentColor
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: activityVM.temperatureInput)
    }
}
