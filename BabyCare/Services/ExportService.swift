import Foundation

enum ExportService {
    /// CSV 문자열 생성 (순수 함수 — 단위 테스트 가능).
    /// 유축량(생산 mL)은 섭취 양(ml)과 별도 컬럼으로 분리 (생산 ≠ 섭취, spec §5.3#2).
    static func makeCSVString(activities: [Activity]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.locale = Locale(identifier: "ko_KR")

        var csv = "날짜,시간,유형,상세,기간(분),양(ml),유축량(ml),체온,메모\n"

        let sorted = activities.sorted { $0.startTime < $1.startTime }
        for a in sorted {
            let date = dateFormatter.string(from: a.startTime)
            let dateParts = date.split(separator: " ")
            let dateStr = String(dateParts.first ?? "")
            let timeStr = String(dateParts.last ?? "")
            let type = a.type.displayName
            var detail = ""
            if let side = a.side { detail = side.displayName }
            if let med = a.medicationName { detail = med }
            let duration = a.duration.map { String(Int($0 / 60)) } ?? ""
            // 유축 row는 유축량(ml) 컬럼에, 그 외는 섭취 양(ml) 컬럼에 — 상호 배타 공란
            let isPumping = a.type.category == .pumping
            let intake = (isPumping ? nil : a.amount).map { String(Int($0)) } ?? ""
            let pumped = (isPumping ? a.amount : nil).map { String(Int($0)) } ?? ""
            let temp = a.temperature.map { String(format: "%.1f", $0) } ?? ""
            let note = (a.note ?? "").replacingOccurrences(of: ",", with: " ")

            csv += "\(dateStr),\(timeStr),\(type),\(detail),\(duration),\(intake),\(pumped),\(temp),\(note)\n"
        }
        return csv
    }

    static func generateCSV(activities: [Activity], babyName: String) -> URL? {
        let csv = makeCSVString(activities: activities)

        let fileName = "\(babyName)_기록_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)).csv"
            .replacingOccurrences(of: "/", with: "-")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            // UTF-8 BOM for Excel compatibility
            let bom = "\u{FEFF}"
            try (bom + csv).write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
}
