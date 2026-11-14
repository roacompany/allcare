import SwiftUI

// MARK: - 저장 뒤 용품 고르기(기록 화면들이 함께 쓴다)

extension View {
    /// 저장 뒤 「사용할 용품 선택」 창. 골랐든 「건너뛰기」든 아래로 내렸든, 창이 닫히면 한 번 `onFinished`(저장한 값).
    /// 🩸 2026-11-14: 기록 화면 4곳이 끝을 「골랐을 때」에만 둬 「건너뛰기」 뒤 단추가 계속 돌았다 — 끝은 닫힘(onDismiss) 한 곳.
    func productPicker<Saved>(
        flow: Binding<RecordSaveFlow<Saved>>,
        onSelect: @escaping (BabyProduct) -> Void,
        onFinished: @escaping (Saved) -> Void
    ) -> some View {
        sheet(
            isPresented: Binding(
                get: { flow.wrappedValue.isPickingProduct },
                set: { if !$0 { flow.wrappedValue.dropCandidates() } }
            ),
            onDismiss: {
                if let value = flow.wrappedValue.pickerClosed() { onFinished(value) }
            }
        ) {
            ProductPickerSheet(products: flow.wrappedValue.productCandidates, onSelect: onSelect)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - ProductPickerSheet

/// 같은 카테고리에 용품이 2개 이상일 때 어떤 용품에서 차감할지 선택하는 시트
struct ProductPickerSheet: View {
    let products: [BabyProduct]
    let onSelect: (BabyProduct) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(products) { product in
                Button {
                    onSelect(product)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: product.category.icon)
                            .font(.title3)
                            .foregroundStyle(AppColors.indigoColor)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let brand = product.brand {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let remaining = product.remainingQuantity {
                            Text("\(remaining)개 남음")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("사용할 용품 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기") { dismiss() }
                }
            }
        }
    }
}
