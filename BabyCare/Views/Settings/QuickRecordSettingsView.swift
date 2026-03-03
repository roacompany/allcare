import SwiftUI

struct QuickRecordSettingsView: View {
    @State private var enabledTypes: [Activity.ActivityType] = QuickRecordSettings.enabledTypes

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        List {
            // 미리보기
            Section {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(enabledTypes, id: \.self) { type in
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(type.color).opacity(0.15))
                                    .frame(height: 52)
                                Image(systemName: type.icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color(type.color))
                            }
                            Text(type.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("미리보기")
            }

            // 타입 선택 + 순서 변경
            Section {
                ForEach(enabledTypes, id: \.self) { type in
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.body)
                            .foregroundStyle(Color(type.color))
                            .frame(width: 28)
                        Text(type.displayName)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .onMove { source, destination in
                    enabledTypes.move(fromOffsets: source, toOffset: destination)
                    save()
                }
                .onDelete { indexSet in
                    guard enabledTypes.count - indexSet.count >= 1 else { return }
                    enabledTypes.remove(atOffsets: indexSet)
                    save()
                }

                // 비활성 타입
                let disabledTypes = QuickRecordSettings.allAvailableTypes.filter { !enabledTypes.contains($0) }
                ForEach(disabledTypes, id: \.self) { type in
                    Button {
                        enabledTypes.append(type)
                        save()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.body)
                                .foregroundStyle(Color(type.color).opacity(0.4))
                                .frame(width: 28)
                            Text(type.displayName)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("빠른 기록 항목")
            } footer: {
                Text("항목을 드래그하여 순서를 변경하거나, 스와이프하여 제거할 수 있습니다. 최소 1개는 유지해야 합니다.")
            }
        }
        .navigationTitle("빠른 기록 설정")
        .environment(\.editMode, .constant(.active))
    }

    private func save() {
        QuickRecordSettings.enabledTypes = enabledTypes
    }
}
