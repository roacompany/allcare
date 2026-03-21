import Foundation

// MARK: - 분석 기간

struct AnalysisPeriod: Codable {
    var from: Date
    var to: Date

    var daysCount: Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

// MARK: - 일별 집계

struct DailyAggregate: Codable {
    var date: Date
    var feedingCount: Int           // 수유 횟수
    var feedingAmountMl: Double     // 수유량 합계 (ml), 분유만 집계
    var sleepMinutes: Double        // 수면 시간 (분)
    var diaperCount: Int            // 기저귀 횟수
    var avgTemperature: Double?     // 평균 체온
    var isMissingData: Bool         // LOCF 채움 여부
    var hasOutlier: Bool            // IQR×3 이상치 플래그
}

// MARK: - Layer 플래그

struct MetricFlag: Codable {
    enum Metric: String, Codable { case feeding, feedingAmount, sleep, diaper, temperature }
    enum Direction: String, Codable { case up, down }
    enum Layer: Int, Codable { case reference = 1, baseline = 2 }

    var metric: Metric
    var layer: Layer
    var direction: Direction
    var sigmaDistance: Double       // 기준선으로부터 σ 거리
    var changePointDate: Date?      // CUSUM 감지 날짜
    var score: Double               // 우선순위 점수
}

// MARK: - 패턴

enum DetectedPattern: String, Codable {
    case growthSpurt = "growth_spurt"                   // 성장급등
    case infectionSuspected = "infection_suspected"     // 감염 의심
    case dehydrationRisk = "dehydration_risk"           // 탈수 위험 (기저귀↓ + 수유↓)
    case mildDehydrationConcern = "mild_dehydration_concern" // 탈수 주의 (기저귀↓만)
    case normalVariation = "normal_variation"           // 정상 변동
}

// MARK: - 분석 결과

struct AnalysisResult: Codable, Identifiable {
    var id: String
    var babyId: String
    var hospitalVisitId: String
    var createdAt: Date
    var period: AnalysisPeriod
    var correctedAgeInDays: Int

    // Layer 결과
    var dailyAggregates: [DailyAggregate]
    var flags: [MetricFlag]
    var patterns: [DetectedPattern]

    // Layer 4 필터 결과
    var prioritizedFlags: [MetricFlag]          // 임상 유의성 통과 플래그
    var checklistItems: [String]                // AI에 넘길 체크리스트 항목
    var disclaimerRequired: Bool

    // AI 리포트 (Claude 응답)
    var aiReport: AIReport?

    init(
        id: String = UUID().uuidString,
        babyId: String,
        hospitalVisitId: String,
        createdAt: Date = Date(),
        period: AnalysisPeriod,
        correctedAgeInDays: Int,
        dailyAggregates: [DailyAggregate] = [],
        flags: [MetricFlag] = [],
        patterns: [DetectedPattern] = [],
        prioritizedFlags: [MetricFlag] = [],
        checklistItems: [String] = [],
        disclaimerRequired: Bool = true,
        aiReport: AIReport? = nil
    ) {
        self.id = id
        self.babyId = babyId
        self.hospitalVisitId = hospitalVisitId
        self.createdAt = createdAt
        self.period = period
        self.correctedAgeInDays = correctedAgeInDays
        self.dailyAggregates = dailyAggregates
        self.flags = flags
        self.patterns = patterns
        self.prioritizedFlags = prioritizedFlags
        self.checklistItems = checklistItems
        self.disclaimerRequired = disclaimerRequired
        self.aiReport = aiReport
    }
}

// MARK: - AI 리포트

struct AIReport: Codable {
    var summary: String
    var keyChanges: [String]
    var checklistItems: [ChecklistItem]
    var generatedAt: Date

    struct ChecklistItem: Codable, Identifiable {
        var id: String
        var question: String
        var isChecked: Bool

        init(id: String = UUID().uuidString, question: String, isChecked: Bool = false) {
            self.id = id
            self.question = question
            self.isChecked = isChecked
        }
    }
}
