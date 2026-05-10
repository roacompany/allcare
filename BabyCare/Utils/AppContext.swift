/// AppContext — 앱의 4가지 사용자 상태를 나타내는 독립 enum.
/// AppState와 독립적 순수 값 타입. Observable/ObservableObject 아님.
/// P1 임신 모드 v2 재설계의 기반 타입.
enum AppContext: Equatable {
    /// 아기도 없고 활성 임신도 없는 상태 (온보딩 진입)
    case empty
    /// 아기가 있고 활성 임신이 없는 상태 (일반 육아 모드)
    case babyOnly
    /// 아기가 없고 활성 임신이 있는 상태 (임신 전용 모드)
    case pregnancyOnly
    /// 아기도 있고 활성 임신도 있는 상태 (육아 + 임신 공존)
    case both
}

extension AppContext {
    /// babies 배열과 pregnancy 옵셔널로부터 AppContext를 결정하는 static factory.
    /// - Parameters:
    ///   - babies: 현재 사용자의 아기 목록
    ///   - pregnancy: 활성 임신 데이터 (없으면 nil)
    /// - Returns: 4-state AppContext
    static func resolve(babies: [Baby], pregnancy: Pregnancy?) -> AppContext {
        let hasBaby = !babies.isEmpty
        let hasPreg = pregnancy != nil
        switch (hasBaby, hasPreg) {
        case (false, false): return .empty
        case (true, false):  return .babyOnly
        case (false, true):  return .pregnancyOnly
        case (true, true):   return .both
        }
    }
}
