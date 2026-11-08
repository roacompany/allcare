import SwiftUI

/// 장소 검색(시안 Search-Move · Search-Hotel) — 맨 위 검색 칸 · 바로 밑 후보 · 첫 줄 「직접 입력」.
/// 🩸 2026-11-06: 후보를 칸 바로 밑에 그리면 아래쪽 칸은 후보 전부가 자판 밑이라 찾는 기능이 없는 것처럼 보였다.
///    그래서 칸이 어디 있든 같은 화면을 따로 연다 — 검색 칸이 늘 맨 위라 후보가 자판 위에 온다.
struct TripPlaceSearchSheet: View {
    let title: String
    let showsAirports: Bool
    /// 주소까지 받는가(숙소). 아니면 이름만 쓰므로 지도에 다시 묻지 않는다(느린 망에서 기다리지 않게).
    let needsAddress: Bool
    let search: PlaceSearchModel
    let onPick: (PlaceSearchModel.Pick) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    /// 주소를 받아 오는 줄 · 그 일.
    @State private var resolvingRowId: String?
    @State private var resolveTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    init(title: String, initialText: String = "", showsAirports: Bool = true, needsAddress: Bool = false, search: PlaceSearchModel,
         onPick: @escaping (PlaceSearchModel.Pick) -> Void) {
        self.title = title
        self.showsAirports = showsAirports
        self.needsAddress = needsAddress
        self.search = search
        self.onPick = onPick
        _text = State(initialValue: initialText)
    }

    private var rows: [TripPlaceSearchRows.Row] {
        TripPlaceSearchRows.rows(text: text, suggestions: search.suggestions, includesAirports: showsAirports)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, TravelStyle.gutter)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            rowButton(row)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(TravelStyle.page)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TravelStyle.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .onAppear {
            search.clear()
            search.search(text)
            focused = true
        }
        .onDisappear {
            resolveTask?.cancel()
            search.clear()
        }
        .onChange(of: text) { _, new in
            search.search(new)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TravelStyle.sub)
            TextField("\(title) 검색", text: $text)
                .travelFont(16, .medium)
                .foregroundStyle(TravelStyle.ink)
                .tint(TravelStyle.primary)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { focused = false }
            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(TravelStyle.clearMark)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("지우기")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.chip))
    }

    private func rowButton(_ row: TripPlaceSearchRows.Row) -> some View {
        Button {
            choose(row)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if resolvingRowId == row.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: row.isTyped ? "pencil" : "mappin.and.ellipse")
                            .font(.system(size: 15))
                            .foregroundStyle(TravelStyle.sub)
                    }
                }
                .frame(width: 18)
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .travelFont(15)
                        .foregroundStyle(TravelStyle.ink)
                    if !row.subtitle.isEmpty {
                        Text(row.subtitle)
                            .travelFont(13)
                            .foregroundStyle(TravelStyle.sub)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 주소를 기다리는 중에 다른 줄을 누르면 앞의 일은 버린다(느린 망에서도 다른 곳을 고를 수 있게).
    private func choose(_ row: TripPlaceSearchRows.Row) {
        resolveTask?.cancel()
        resolvingRowId = nil
        if let pick = row.pick {
            finish(pick)
        } else if let suggestion = row.suggestion {
            guard needsAddress else {
                finish(PlaceSearchModel.nameOnlyPick(suggestion))
                return
            }
            resolvingRowId = row.id
            resolveTask = Task {
                let pick = await search.resolve(suggestion)
                // 취소로 닫은 뒤 늦게 온 답은 버린다 — 손님이 그사이 고른 값을 덮으면 안 된다.
                guard !Task.isCancelled else { return }
                finish(pick)
            }
        }
    }

    private func finish(_ pick: PlaceSearchModel.Pick) {
        onPick(pick)
        dismiss()
    }
}
