import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(ActivityViewModel.self) var activityVM
    @Environment(BabyViewModel.self) var babyVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(ProductViewModel.self) var productVM
    @Environment(HealthViewModel.self) var healthVM
    @Environment(AnnouncementViewModel.self) var announcementVM

    @State var showBabySelector = false
    @State var editingActivity: Activity?
    @State var productCandidates: [BabyProduct] = []
    @State var savedActivityType: Activity.ActivityType?
    @State var lastSavedActivity: Activity?
    @State var quickInputType: Activity.ActivityType?

    let feedingColor = AppColors.feedingColor
    let sleepColor = AppColors.sleepColor
    let diaperColor = AppColors.diaperColor

    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AnnouncementBanner()
                    alertBannersSection
                    quickActionsSection
                    soundShortcutCard
                    predictionSection
                    summaryCardsSection
                    aiAdviceShortcut
                    timelineSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable {
                await loadData()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    headerView
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(item: $editingActivity) { activity in
            ActivityEditSheet(activity: activity) { updated in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await activityVM.updateActivity(updated, userId: userId)
                }
            }
            .presentationDetents([.medium])
        }
        .overlay(alignment: .top) {
            if let type = savedActivityType {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                    Text("\(type.displayName) 저장됨")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    if lastSavedActivity != nil {
                        Divider()
                            .frame(height: 16)
                            .overlay(.white.opacity(0.5))
                        Button("수정") {
                            editingActivity = lastSavedActivity
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(type.color))
                        .shadow(color: Color(type.color).opacity(0.4), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .sheet(item: $quickInputType) { type in
            QuickInputSheet(type: type) { activity in
                Task { await quickSaveWithData(activity) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(
            get: { !productCandidates.isEmpty },
            set: { if !$0 { productCandidates = [] } }
        )) {
            ProductPickerSheet(products: productCandidates) { selected in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await productVM.deductFromProduct(selected, userId: userId)
                }
                productCandidates = []
            }
            .presentationDetents([.medium])
        }
    }
}
