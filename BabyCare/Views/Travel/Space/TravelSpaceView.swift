import SwiftUI

/// 여행 공간 — 베이비케어 아래 바 「여행」에서 같은 자리에 겹쳐 연다(설계 2026-11-05 §2 · §7).
/// 자기 아래 바(왼쪽 「←」 + 홈·일정·예약·준비 · 캔버스 Version 84) · 칸마다 NavigationStack 하나 · 「←」로 베이비케어에 돌아간다.
/// 아이 화면은 홈에서 밀어 연다(「‹ 홈」).
struct TravelSpaceView: View {
    let initialTripId: String?
    /// 베이비케어로 돌아가기(아래 바 「←」).
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var listVM = TripListViewModel()
    @State private var selectedTripId: String?
    @State private var detail: TripDetailViewModel?
    @State private var tab: TravelTab = .home
    /// 준비 칸 — 담당 거르기 · 할 일/규칙(홈 「n개」가 할 일·전체로 연다).
    @State private var assigneeFilter: TripAssigneeFilter = .all
    @State private var prepSection: TravelPrepSection = .tasks
    /// 일정 칸에서 고른 날(홈 「일정 전체」가 그날로 바꾼다).
    @State private var planDay: Date?
    /// 홈에서 밀어 연 화면(아이).
    @State private var homePath: [TravelHomeRoute] = []
    @State private var showCreate = false
    @State private var pendingDelete: Trip?
    @State private var didLoad = false

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { proxy in
            tabs(bottomInset: TravelBottomBar.contentInset(safeBottom: proxy.safeAreaInsets.bottom))
                .overlay(alignment: .bottom) {
                    TravelBottomBar(tab: $tab, onBack: onClose)
                        // 안전 영역 아래로 내려 화면 맨 아래에서 22 위에 뜨게(참고 화면).
                        .offset(y: proxy.safeAreaInsets.bottom - TravelBottomBar.screenBottom)
                }
        }
        .background(TravelStyle.page.ignoresSafeArea())
        .tint(TravelStyle.ink)
        .task(id: babyVM.selectedBaby?.id ?? "") {
            await reload()
        }
        .task(id: selectedTripId ?? "") {
            await openDetail()
        }
        .task(id: detail?.itinerary.routeQuestions ?? []) {
            await detail?.loadRoutes()
        }
        .task(id: detail?.trip.id ?? "") {
            // 항공편 실시간 — 열 때 한 번, 오늘 편이 있으면 5분마다(공항 목록은 당일치뿐).
            guard let model = detail else { return }
            while !Task.isCancelled {
                await model.refreshFlightStatus()
                guard model.hasFlightToday else { break }
                try? await Task.sleep(for: .seconds(300))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let model = detail else { return }
            Task {
                await model.refreshFlightStatus()
                await model.loadRoutes()  // 망이 끊겨 못 받은 구간을 다시 묻는다
            }
        }
        .onChange(of: selectedTripId) { _, _ in
            // 여행을 바꾸면 거르기·칸·고른 날·밀어 연 화면을 처음으로(보이지 않는 거르기가 남지 않게 · 검토 11/5).
            assigneeFilter = .all
            prepSection = .tasks
            planDay = nil
            homePath = []
        }
        .onChange(of: detail?.isDeleted ?? false) { _, deleted in
            // 다른 보호자가 지웠으면 목록을 다시 읽고 다음 여행으로.
            guard deleted else { return }
            selectedTripId = nil
            Task { await reload() }
        }
        .sheet(isPresented: $showCreate) {
            TripCreateSheet { city, startDay, endDay in
                Task { await create(city: city, startDay: startDay, endDay: endDay) }
            }
        }
        .confirmationDialog("이 여행을 삭제할까요?", isPresented: deleteBinding, titleVisibility: .visible, presenting: pendingDelete) { trip in
            Button("여행 삭제", role: .destructive) {
                Task { await delete(trip) }
            }
        } message: { _ in
            Text("예약과 체크한 할 일도 함께 삭제돼요. 되돌릴 수 없어요.")
        }
    }

    /// 네 칸 — 시스템 아래 바는 숨기고(아래 바는 직접 그린다) 칸 상태는 TabView 가 지킨다.
    private func tabs(bottomInset: CGFloat) -> some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                // 뿌리 제목 「홈」 — 막대는 숨기지만, 밀어 연 아이 화면의 뒤로 버튼이 「‹ 홈」으로 읽힌다(시안 Child).
                root(bottomInset: bottomInset, title: "홈") { vm in
                    TravelHomeView(vm: vm, trips: listVM.trips,
                                   onSelect: { selectedTripId = $0.id },
                                   onCreate: { showCreate = true },
                                   onDelete: { pendingDelete = $0 },
                                   onDeleteTrip: { Task { await delete(vm.trip) } },
                                   onShowSchedule: { day in
                                       planDay = day
                                       tab = .plan
                                   },
                                   onShowTasks: { showTasks() },
                                   onShowChild: { homePath.append(.child) })
                }
                .navigationDestination(for: TravelHomeRoute.self) { route in
                    switch route {
                    case .child:
                        Group {
                            if let detail {
                                TravelChildView(vm: detail)
                            }
                        }
                        .travelPushedPage(bottomInset: bottomInset)
                    }
                }
            }
            .tag(TravelTab.home)

            NavigationStack {
                root(bottomInset: bottomInset) { vm in  // 칸 이름은 화면 머리(시안 22 굵게)에 있다
                    TravelPlanView(vm: vm, day: $planDay, onShowTasks: { showTasks() })
                }
            }
            .tag(TravelTab.plan)

            NavigationStack {
                root(bottomInset: bottomInset) { vm in
                    TravelBookingsView(vm: vm)
                }
            }
            .tag(TravelTab.bookings)

            NavigationStack {
                root(bottomInset: bottomInset) { vm in
                    TravelPrepView(vm: vm, section: $prepSection, filter: $assigneeFilter)
                }
            }
            .tag(TravelTab.prep)
        }
    }

    // MARK: - 칸 바탕 — 여행이 있으면 내용, 없으면 「여행 만들기」

    private func root<Content: View>(bottomInset: CGFloat, title: String = "",
                                     @ViewBuilder content: @escaping (TripDetailViewModel) -> Content) -> some View {
        Group {
            if let detail {
                content(detail)
            } else if !didLoad || listVM.isLoading || selectedTripId != nil {
                // 고른 여행의 뷰모델을 만드는 사이에 「여행 만들기」가 한 번 깜빡이지 않게.
                ProgressView()
            } else if listVM.errorMessage != nil {
                ContentUnavailableView {
                    Label("여행을 불러오지 못했어요", systemImage: "exclamationmark.circle")
                } description: {
                    Text("잠시 뒤 다시 시도해 주세요.")
                } actions: {
                    Button("다시 시도") { Task { await reload() } }
                }
            } else {
                TravelEmptyView(canCreate: babyVM.selectedBaby != nil) { showCreate = true }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // 칸마다 이름이 화면 머리에 있다 — 빈 위 막대(제목 없는 내비게이션 바)는 숨긴다(PO 11/6 「우측 상단 연필… 이상한데」).
        // 밀어 연 화면(홈 → 아이)만 막대를 다시 보인다(travelPushedPage).
        .toolbar(.hidden, for: .navigationBar)
        .background(TravelStyle.page)
        // 아래 바는 직접 그린다(왼쪽 「←」 + 떠 있는 둥근 바) — 내용은 그 위에서 끝나게.
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: bottomInset)
        }
    }

    // MARK: - 읽기 · 만들기 · 지우기

    private func owner(_ current: String?) -> String? {
        guard let current else { return nil }
        return babyVM.dataUserId(currentUserId: current)
    }

    private var selectedTrip: Trip? {
        guard let selectedTripId else { return nil }
        return listVM.trips.first { $0.id == selectedTripId }
    }

    private func reload() async {
        let current = authVM.currentUserId
        await listVM.load(currentUserId: current, ownerUserId: owner(current), babyId: babyVM.selectedBaby?.id)
        didLoad = true
        let trips = listVM.trips
        if selectedTripId == nil || !trips.contains(where: { $0.id == selectedTripId }) {
            let fromCard = initialTripId.flatMap { id in trips.first { $0.id == id }?.id }
            selectedTripId = fromCard
                ?? listVM.nextTrip(today: Date(), calendar: calendar)?.id
                ?? trips.max { $0.startDay < $1.startDay }?.id
        }
        if selectedTripId == nil { detail = nil }
    }

    /// 고른 여행의 뷰모델 — 열린 동안 저장소를 지켜본다(여행을 바꾸면 앞의 것은 끊긴다).
    private func openDetail() async {
        guard let current = authVM.currentUserId, let trip = selectedTrip else {
            detail = nil
            return
        }
        let baby = babyVM.babies.first { $0.id == trip.babyId } ?? babyVM.selectedBaby
        let ownerId = baby.flatMap { BabyViewModel.ownerUserId(for: $0, currentUserId: current) } ?? current
        let model = TripDetailViewModel(trip: trip, ownerUserId: ownerId, currentUserId: current,
                                        babyBirthDate: baby?.birthDate ?? Date())
        detail = model
        async let child: Void = model.loadChild()
        await model.observe()
        await child
    }

    private func create(city: String, startDay: String, endDay: String) async {
        let current = authVM.currentUserId
        let trip = await listVM.create(city: city, countryCode: "JP", startDay: startDay, endDay: endDay,
                                       currentUserId: current, ownerUserId: owner(current), babyId: babyVM.selectedBaby?.id)
        if let trip {
            selectedTripId = trip.id
            homePath = []
            tab = .home
        }
    }

    private func delete(_ trip: Trip) async {
        // 먼저 닫는다 — 열린 여행의 읽기가 지우기 뒤에 끝나 알림을 다시 걸지 않게(검토 11/5).
        let wasSelected = selectedTripId == trip.id
        if wasSelected {
            selectedTripId = nil
            detail = nil
        }
        let current = authVM.currentUserId
        await listVM.delete(trip, currentUserId: current, ownerUserId: owner(current))
        if wasSelected { await reload() }
    }

    /// 준비 칸 할 일(전체)로 — 홈 「n개」.
    private func showTasks() {
        assigneeFilter = .all
        prepSection = .tasks
        tab = .prep
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

/// 홈에서 밀어 여는 화면.
enum TravelHomeRoute: Hashable {
    case child
}

private extension View {
    /// 홈에서 밀려 들어간 화면 — 시스템 위 막대를 보인다(뒤로 「‹ 홈」 · 쓸어서 뒤로 가기) · 시스템 탭 바는 숨김 · 아래 바 높이만큼 비움.
    func travelPushedPage(bottomInset: CGFloat) -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TravelStyle.page)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: bottomInset)
            }
    }
}

/// 여행이 없을 때 — 시안 「처음 열었을 때」의 말 · 예시 값은 넣지 않는다(11/4 PO 「비워놓고」).
struct TravelEmptyView: View {
    let canCreate: Bool
    let onCreate: () -> Void

    /// 시안 Welcome — 제목 24 굵게(줄 1.4) · 설명 15(줄 1.55 · #333D4B) · 아래 primary 버튼(높이 52 · 16 굵게) + 13 회색.
    /// 예시 카드(예시 값)는 넣지 않는다 — 실제 여행으로 오해하지 않게.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("아이와 가는 여행,\n우리 아이에 맞춰 챙겨요")
                .travelFont(24, .bold, tracking: -0.03)
                .travelLineHeight(1.4, size: 24)
                .foregroundStyle(TravelStyle.ink)
            Text("아이 기록과 등록한 예약을 보고 항공사 신청, 입국 규칙, 공항 수유실까지 알려 드려요.")
                .travelFont(15)
                .travelLineHeight(1.55, size: 15)
                .foregroundStyle(TravelStyle.body)
                .padding(.top, 10)
            Spacer()
            VStack(spacing: 4) {
                if canCreate {
                    Button(action: onCreate) {
                        Text("여행 만들기")
                            .travelFont(16, .semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.primary))
                    }
                    .buttonStyle(.plain)
                    Text("함께 기록하는 가족도 같은 여행을 봐요")
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("아기를 먼저 등록하면 여행을 만들 수 있어요")
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, TravelStyle.gutter)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TravelStyle.page)
    }
}
