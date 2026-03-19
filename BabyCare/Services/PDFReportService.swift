import UIKit
import PDFKit

/// 소아과 진료용 PDF 리포트 생성 서비스
/// 수유량 추이, 수면 패턴, 체온 이력, 성장 곡선 요약을 포함
enum PDFReportService {

    // MARK: - Public API

    /// 최근 7일 또는 30일간의 기록을 PDF로 생성
    static func generateReport(
        baby: Baby,
        activities: [Activity],
        growthRecords: [GrowthRecord],
        periodDays: Int
    ) -> URL? {
        let pageWidth: CGFloat = 595.0   // A4
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 40.0
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let dateStr = DateFormatters.fullDate.string(from: Date())
        let periodLabel = periodDays == 7 ? "주간" : "월간"
        let fileName = "\(baby.name)_\(periodLabel)리포트_\(dateStr).pdf"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -periodDays, to: endDate) ?? endDate
        let filtered = activities.filter { $0.startTime >= startDate.startOfDay && $0.startTime <= endDate.endOfDay }

        let data = renderer.pdfData { context in
            var currentY: CGFloat = 0.0

            // ── Page 1: 표지 + 요약 ────────────────────────────
            context.beginPage()
            currentY = margin

            // Title
            currentY = drawText(
                "베이비케어 건강 리포트",
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                font: .systemFont(ofSize: 22, weight: .bold),
                color: UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1),
                alignment: .center
            )
            currentY += 8

            // Baby info
            let babyInfoText = "\(baby.name) (\(baby.gender.displayName)) · \(baby.ageText)"
            currentY = drawText(
                babyInfoText,
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                font: .systemFont(ofSize: 14, weight: .medium),
                color: .darkGray,
                alignment: .center
            )
            currentY += 4

            // Period & date
            let periodText = "\(periodLabel) 리포트 (\(DateFormatters.shortDate.string(from: startDate)) ~ \(DateFormatters.shortDate.string(from: endDate)))"
            currentY = drawText(
                periodText,
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                font: .systemFont(ofSize: 12),
                color: .gray,
                alignment: .center
            )
            currentY += 4

            currentY = drawText(
                "생성일: \(dateStr)",
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                font: .systemFont(ofSize: 10),
                color: .lightGray,
                alignment: .center
            )
            currentY += 20

            // Divider
            currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
            currentY += 16

            // ── 요약 카드 ────────────────────────────
            currentY = drawSectionTitle("종합 요약", at: CGPoint(x: margin, y: currentY), width: contentWidth)
            currentY += 8

            let feedings = filtered.filter { $0.type.category == .feeding }
            let sleeps = filtered.filter { $0.type == .sleep }
            let diapers = filtered.filter { $0.type.category == .diaper }
            let temperatures = filtered.filter { $0.temperature != nil }

            let totalDays = max(1, periodDays)
            let summaryItems: [(String, String)] = [
                ("총 수유 횟수", "\(feedings.count)회 (일평균 \(String(format: "%.1f", Double(feedings.count) / Double(totalDays)))회)"),
                ("총 분유량", "\(Int(feedings.compactMap(\.amount).reduce(0, +)))ml"),
                ("총 수면 횟수", "\(sleeps.count)회"),
                ("총 수면 시간", String(format: "%.1f시간", sleeps.compactMap(\.duration).reduce(0, +) / 3600)),
                ("일평균 수면", String(format: "%.1f시간", sleeps.compactMap(\.duration).reduce(0, +) / 3600 / Double(totalDays))),
                ("총 기저귀 교체", "\(diapers.count)회"),
                ("체온 측정 횟수", "\(temperatures.count)회"),
            ]

            for (label, value) in summaryItems {
                currentY = drawKeyValue(label: label, value: value, at: CGPoint(x: margin, y: currentY), width: contentWidth)
            }
            currentY += 16

            // ── 수유 상세 ────────────────────────────
            currentY = checkPageBreak(context: context, currentY: currentY, needed: 200, pageHeight: pageHeight, margin: margin)
            currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
            currentY += 12
            currentY = drawSectionTitle("수유 기록 상세", at: CGPoint(x: margin, y: currentY), width: contentWidth)
            currentY += 8

            // Daily feeding table
            let feedingByDay = groupByDay(feedings, startDate: startDate, days: periodDays)
            currentY = drawDailyTable(
                context: context,
                title: "일자",
                headers: ["날짜", "횟수", "분유량(ml)", "모유(분)"],
                rows: feedingByDay.map { day in
                    let dayFeedings = day.activities
                    let bottleMl = Int(dayFeedings.filter { $0.type == .feedingBottle }.compactMap(\.amount).reduce(0, +))
                    let breastMin = Int(dayFeedings.filter { $0.type == .feedingBreast }.compactMap(\.duration).reduce(0, +) / 60)
                    return [day.dateLabel, "\(dayFeedings.count)", "\(bottleMl)", "\(breastMin)"]
                },
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                pageHeight: pageHeight,
                margin: margin
            )
            currentY += 12

            // Feeding interval analysis
            currentY = checkPageBreak(context: context, currentY: currentY, needed: 80, pageHeight: pageHeight, margin: margin)
            let sortedFeedings = feedings.sorted { $0.startTime < $1.startTime }
            if sortedFeedings.count >= 2 {
                var intervals: [TimeInterval] = []
                for i in 1..<sortedFeedings.count {
                    intervals.append(sortedFeedings[i].startTime.timeIntervalSince(sortedFeedings[i-1].startTime))
                }
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                let minInterval = intervals.min() ?? 0
                let maxInterval = intervals.max() ?? 0
                currentY = drawKeyValue(label: "평균 수유 간격", value: avgInterval.shortDuration, at: CGPoint(x: margin, y: currentY), width: contentWidth)
                currentY = drawKeyValue(label: "최소 간격", value: minInterval.shortDuration, at: CGPoint(x: margin, y: currentY), width: contentWidth)
                currentY = drawKeyValue(label: "최대 간격", value: maxInterval.shortDuration, at: CGPoint(x: margin, y: currentY), width: contentWidth)
            }
            currentY += 12

            // ── 수면 상세 ────────────────────────────
            currentY = checkPageBreak(context: context, currentY: currentY, needed: 200, pageHeight: pageHeight, margin: margin)
            currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
            currentY += 12
            currentY = drawSectionTitle("수면 기록 상세", at: CGPoint(x: margin, y: currentY), width: contentWidth)
            currentY += 8

            let sleepByDay = groupByDay(sleeps, startDate: startDate, days: periodDays)
            currentY = drawDailyTable(
                context: context,
                title: "일자",
                headers: ["날짜", "횟수", "총 수면(시간)", "최장 수면"],
                rows: sleepByDay.map { day in
                    let totalHours = String(format: "%.1f", day.activities.compactMap(\.duration).reduce(0, +) / 3600)
                    let longest = day.activities.compactMap(\.duration).max()
                    let longestStr = longest.map { TimeInterval($0).shortDuration } ?? "-"
                    return [day.dateLabel, "\(day.activities.count)", totalHours, longestStr]
                },
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                pageHeight: pageHeight,
                margin: margin
            )
            currentY += 12

            // ── 체온 이력 ────────────────────────────
            if !temperatures.isEmpty {
                currentY = checkPageBreak(context: context, currentY: currentY, needed: 150, pageHeight: pageHeight, margin: margin)
                currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
                currentY += 12
                currentY = drawSectionTitle("체온 이력", at: CGPoint(x: margin, y: currentY), width: contentWidth)
                currentY += 8

                let tempValues = temperatures.compactMap(\.temperature)
                if let maxTemp = tempValues.max(), let minTemp = tempValues.min() {
                    let avgTemp = tempValues.reduce(0, +) / Double(tempValues.count)
                    currentY = drawKeyValue(label: "평균 체온", value: String(format: "%.1f°C", avgTemp), at: CGPoint(x: margin, y: currentY), width: contentWidth)
                    currentY = drawKeyValue(label: "최고 체온", value: String(format: "%.1f°C", maxTemp), at: CGPoint(x: margin, y: currentY), width: contentWidth)
                    currentY = drawKeyValue(label: "최저 체온", value: String(format: "%.1f°C", minTemp), at: CGPoint(x: margin, y: currentY), width: contentWidth)
                    currentY += 4

                    // Fever alert
                    let feverCount = tempValues.filter { $0 >= 37.5 }.count
                    if feverCount > 0 {
                        currentY = drawText(
                            "⚠ 37.5°C 이상 기록: \(feverCount)회",
                            at: CGPoint(x: margin, y: currentY),
                            width: contentWidth,
                            font: .systemFont(ofSize: 11, weight: .semibold),
                            color: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)
                        )
                    }
                }
                currentY += 8

                // Individual records
                let sortedTemps = temperatures.sorted { $0.startTime < $1.startTime }
                currentY = drawDailyTable(
                    context: context,
                    title: "체온",
                    headers: ["날짜/시간", "체온(°C)", "메모"],
                    rows: sortedTemps.prefix(30).map { act in
                        let dateTimeStr = DateFormatters.dateTime.string(from: act.startTime)
                        let tempStr = act.temperature.map { String(format: "%.1f", $0) } ?? "-"
                        let noteStr = act.note ?? "-"
                        return [dateTimeStr, tempStr, noteStr]
                    },
                    at: CGPoint(x: margin, y: currentY),
                    width: contentWidth,
                    pageHeight: pageHeight,
                    margin: margin
                )
                currentY += 12
            }

            // ── 성장 곡선 요약 ────────────────────────────
            let recentGrowth = growthRecords.filter { $0.date >= startDate.startOfDay }
            if !recentGrowth.isEmpty {
                currentY = checkPageBreak(context: context, currentY: currentY, needed: 150, pageHeight: pageHeight, margin: margin)
                currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
                currentY += 12
                currentY = drawSectionTitle("성장 기록", at: CGPoint(x: margin, y: currentY), width: contentWidth)
                currentY += 8

                currentY = drawDailyTable(
                    context: context,
                    title: "성장",
                    headers: ["날짜", "키(cm)", "몸무게(kg)", "머리둘레(cm)"],
                    rows: recentGrowth.map { record in
                        let dateStr = DateFormatters.shortDate.string(from: record.date)
                        let height = record.height.map { String(format: "%.1f", $0) } ?? "-"
                        let weight = record.weight.map { String(format: "%.2f", $0) } ?? "-"
                        let head = record.headCircumference.map { String(format: "%.1f", $0) } ?? "-"
                        return [dateStr, height, weight, head]
                    },
                    at: CGPoint(x: margin, y: currentY),
                    width: contentWidth,
                    pageHeight: pageHeight,
                    margin: margin
                )
                currentY += 12
            }

            // 전체 성장 추이 (마지막 5개)
            let lastFiveGrowth = growthRecords.suffix(5)
            if lastFiveGrowth.count >= 2 {
                currentY = checkPageBreak(context: context, currentY: currentY, needed: 100, pageHeight: pageHeight, margin: margin)
                if recentGrowth.isEmpty {
                    currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
                    currentY += 12
                    currentY = drawSectionTitle("성장 추이 (최근 5회)", at: CGPoint(x: margin, y: currentY), width: contentWidth)
                    currentY += 8
                } else {
                    currentY = drawText(
                        "최근 성장 추이",
                        at: CGPoint(x: margin, y: currentY),
                        width: contentWidth,
                        font: .systemFont(ofSize: 13, weight: .semibold),
                        color: .darkGray
                    )
                    currentY += 4
                }

                if let first = lastFiveGrowth.first, let last = lastFiveGrowth.last {
                    if let h1 = first.height, let h2 = last.height {
                        currentY = drawKeyValue(label: "키 변화", value: String(format: "%.1fcm → %.1fcm (%+.1fcm)", h1, h2, h2 - h1), at: CGPoint(x: margin, y: currentY), width: contentWidth)
                    }
                    if let w1 = first.weight, let w2 = last.weight {
                        currentY = drawKeyValue(label: "몸무게 변화", value: String(format: "%.2fkg → %.2fkg (%+.2fkg)", w1, w2, w2 - w1), at: CGPoint(x: margin, y: currentY), width: contentWidth)
                    }
                }
            }

            // ── 기저귀 요약 ────────────────────────────
            currentY = checkPageBreak(context: context, currentY: currentY, needed: 100, pageHeight: pageHeight, margin: margin)
            currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
            currentY += 12
            currentY = drawSectionTitle("기저귀 기록 요약", at: CGPoint(x: margin, y: currentY), width: contentWidth)
            currentY += 8

            let wetCount = diapers.filter { $0.type == .diaperWet || $0.type == .diaperBoth }.count
            let dirtyCount = diapers.filter { $0.type == .diaperDirty || $0.type == .diaperBoth }.count
            currentY = drawKeyValue(label: "소변 포함", value: "\(wetCount)회", at: CGPoint(x: margin, y: currentY), width: contentWidth)
            currentY = drawKeyValue(label: "대변 포함", value: "\(dirtyCount)회", at: CGPoint(x: margin, y: currentY), width: contentWidth)
            currentY = drawKeyValue(label: "일평균 교체", value: String(format: "%.1f회", Double(diapers.count) / Double(totalDays)), at: CGPoint(x: margin, y: currentY), width: contentWidth)

            // Stool color alerts
            let abnormalStools = diapers.filter { $0.stoolColor?.needsAttention == true }
            if !abnormalStools.isEmpty {
                currentY += 4
                currentY = drawText(
                    "⚠ 주의가 필요한 대변 색상 \(abnormalStools.count)회 (붉은색/흰색)",
                    at: CGPoint(x: margin, y: currentY),
                    width: contentWidth,
                    font: .systemFont(ofSize: 11, weight: .semibold),
                    color: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)
                )
            }

            // ── Footer ────────────────────────────
            currentY = checkPageBreak(context: context, currentY: currentY, needed: 60, pageHeight: pageHeight, margin: margin)
            currentY = max(currentY + 20, pageHeight - margin - 40)
            currentY = drawDivider(y: currentY, x: margin, width: contentWidth)
            currentY += 8
            _ = drawText(
                "이 리포트는 베이비케어 앱에서 자동 생성되었습니다.\n소아과 진료 시 참고 자료로 활용하세요. 의학적 판단은 반드시 전문의와 상담하세요.",
                at: CGPoint(x: margin, y: currentY),
                width: contentWidth,
                font: .systemFont(ofSize: 9),
                color: .lightGray,
                alignment: .center
            )
        }

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Drawing Helpers

    @discardableResult
    private static func drawText(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor = .black,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = 2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let rect = CGRect(x: point.x, y: point.y, width: width, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: boundingRect.height), withAttributes: attributes)
        return point.y + boundingRect.height
    }

    private static func drawSectionTitle(_ title: String, at point: CGPoint, width: CGFloat) -> CGFloat {
        // Section icon bar
        let barRect = CGRect(x: point.x, y: point.y, width: 4, height: 18)
        UIColor(red: 0.4, green: 0.4, blue: 0.7, alpha: 1).setFill()
        UIBezierPath(roundedRect: barRect, cornerRadius: 2).fill()

        return drawText(
            title,
            at: CGPoint(x: point.x + 12, y: point.y),
            width: width - 12,
            font: .systemFont(ofSize: 16, weight: .bold),
            color: UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1)
        )
    }

    private static func drawKeyValue(label: String, value: String, at point: CGPoint, width: CGFloat) -> CGFloat {
        let labelWidth = width * 0.4
        _ = drawText(label, at: point, width: labelWidth, font: .systemFont(ofSize: 11), color: .gray)
        let valueY = drawText(value, at: CGPoint(x: point.x + labelWidth, y: point.y), width: width - labelWidth, font: .systemFont(ofSize: 11, weight: .medium), color: .darkGray)
        return valueY + 2
    }

    private static func drawDivider(y: CGFloat, x: CGFloat, width: CGFloat) -> CGFloat {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        UIColor(white: 0.85, alpha: 1).setStroke()
        path.lineWidth = 0.5
        path.stroke()
        return y + 1
    }

    /// 테이블 형태로 데이터를 그림 (자동 페이지 넘김)
    @discardableResult
    private static func drawDailyTable(
        context: UIGraphicsPDFRendererContext,
        title: String,
        headers: [String],
        rows: [[String]],
        at point: CGPoint,
        width: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        guard !rows.isEmpty else {
            return drawText("데이터 없음", at: point, width: width, font: .systemFont(ofSize: 10), color: .lightGray)
        }

        let colCount = headers.count
        let colWidth = width / CGFloat(colCount)
        let rowHeight: CGFloat = 18.0
        var currentY = point.y

        // Header
        let headerBgRect = CGRect(x: point.x, y: currentY, width: width, height: rowHeight)
        UIColor(red: 0.94, green: 0.94, blue: 0.97, alpha: 1).setFill()
        UIBezierPath(roundedRect: headerBgRect, cornerRadius: 3).fill()

        for (i, header) in headers.enumerated() {
            _ = drawText(
                header,
                at: CGPoint(x: point.x + CGFloat(i) * colWidth + 4, y: currentY + 2),
                width: colWidth - 8,
                font: .systemFont(ofSize: 9, weight: .semibold),
                color: UIColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 1),
                alignment: i == 0 ? .left : .center
            )
        }
        currentY += rowHeight

        // Data rows
        for (rowIdx, row) in rows.enumerated() {
            if currentY + rowHeight > pageHeight - margin {
                context.beginPage()
                currentY = margin
            }

            // Alternating row background
            if rowIdx % 2 == 1 {
                let bg = CGRect(x: point.x, y: currentY, width: width, height: rowHeight)
                UIColor(white: 0.97, alpha: 1).setFill()
                UIRectFill(bg)
            }

            for (i, cell) in row.prefix(colCount).enumerated() {
                _ = drawText(
                    cell,
                    at: CGPoint(x: point.x + CGFloat(i) * colWidth + 4, y: currentY + 3),
                    width: colWidth - 8,
                    font: .systemFont(ofSize: 9),
                    color: .darkGray,
                    alignment: i == 0 ? .left : .center
                )
            }
            currentY += rowHeight
        }

        return currentY
    }

    private static func checkPageBreak(
        context: UIGraphicsPDFRendererContext,
        currentY: CGFloat,
        needed: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        if currentY + needed > pageHeight - margin {
            context.beginPage()
            return margin
        }
        return currentY
    }

    // MARK: - Data Grouping

    private struct DayGroup {
        let dateLabel: String
        let activities: [Activity]
    }

    private static func groupByDay(_ activities: [Activity], startDate: Date, days: Int) -> [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { $0.startTime.startOfDay }

        var result: [DayGroup] = []
        for dayOffset in 0..<days {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: startDate.startOfDay)!
            let dayActivities = grouped[day] ?? []
            guard !dayActivities.isEmpty else { continue }
            let label = DateFormatters.shortDate.string(from: day)
            result.append(DayGroup(dateLabel: label, activities: dayActivities))
        }
        return result
    }
}
