import SwiftUI
import WidgetKit

/// 잠금화면 인라인 위젯 — 한 줄 텍스트
struct LockScreenInlineView: View {
    let entry: BabyCareEntry

    var body: some View {
        if entry.isFeedingOverdue {
            Text("수유 시간이 지났어요!")
        } else {
            Text("다음 수유 \(entry.nextFeedingText)")
        }
    }
}
