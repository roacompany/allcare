import Foundation

/// AI 출력 가드레일 서비스
/// - 금지어 필터링 (진단명, 약물, 의학적 판단)
/// - 면책 문구 자동 삽입
/// - AI 라벨 지원 (AI 기본법 2026.1 대응)
enum AIGuardrailService {

    // MARK: - 면책 문구

    static let disclaimer = "이 정보는 일반적인 육아 참고 자료이며, 의학적 진단이나 처방을 대체하지 않습니다."

    static let aiLabel = "AI 생성"

    // MARK: - 공개 API

    /// AI 응답 전체 후처리: 금지어 필터 → 면책 문구 삽입
    static func filter(_ text: String) -> String {
        let filtered = applyProhibitedWordFilter(text)
        return appendDisclaimer(filtered)
    }

    /// 금지어 필터만 적용 (면책 문구 없이)
    static func filterOnly(_ text: String) -> String {
        applyProhibitedWordFilter(text)
    }

    /// 면책 문구만 추가
    static func appendDisclaimer(_ text: String) -> String {
        "\(text)\n\n\(disclaimer)"
    }

    // MARK: - 금지어 필터 엔진

    static func applyProhibitedWordFilter(_ text: String) -> String {
        var result = text

        for rule in prohibitedRules {
            for keyword in rule.keywords {
                if result.contains(keyword) {
                    result = applyRule(text: result, keyword: keyword, rule: rule)
                }
            }
        }

        return result
    }

    private static func applyRule(text: String, keyword: String, rule: ProhibitedRule) -> String {
        // 문장 단위로 교체: 금지어가 포함된 문장을 대체 문구로 교체
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".。\n"))
        var result: [String] = []

        for sentence in sentences {
            if sentence.contains(keyword) {
                // 허용 예외 확인
                if let exception = rule.exception, exception(sentence) {
                    result.append(sentence)
                } else {
                    // 중복 대체 문구 방지
                    if !result.contains(where: { $0.trimmingCharacters(in: .whitespaces) == rule.replacement }) {
                        result.append(rule.replacement)
                    }
                }
            } else {
                result.append(sentence)
            }
        }

        return result.joined(separator: ". ")
            .replacingOccurrences(of: ". . ", with: ". ")
            .replacingOccurrences(of: "..  ", with: ". ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 금지어 규칙 정의

    struct ProhibitedRule: Sendable {
        let category: Category
        let keywords: [String]
        let replacement: String
        /// 예외 조건: 해당 문장이 이 조건을 만족하면 필터링하지 않음
        let exception: (@Sendable (String) -> Bool)?

        enum Category: String, Sendable {
            case diagnosis = "진단명"
            case medication = "약물"
            case medicalJudgment = "의학적 판단"
        }
    }

    static let prohibitedRules: [ProhibitedRule] = [
        // ─────────────────────────────────────────
        // 카테고리 1: 진단명
        // ─────────────────────────────────────────
        ProhibitedRule(
            category: .diagnosis,
            keywords: [
                // 발달 장애
                "자폐", "자폐증", "자폐 스펙트럼", "ASD",
                "ADHD", "주의력결핍", "과잉행동장애", "주의력 결핍",
                "발달 지연", "발달지연", "발달장애", "발달 장애",
                "지적 장애", "지적장애", "정신지체",
                "언어 지연", "언어지연", "언어장애", "언어 장애",
                "학습 장애", "학습장애",
                // 성장
                "성장 부진", "성장부진", "성장 장애", "성장장애",
                "왜소증", "저신장", "저체중아",
                "비만", "소아비만", "과체중",
                // 수면
                "수면 장애", "수면장애", "불면증", "수면무호흡",
                "야경증", "몽유병",
                // 정서
                "우울증", "불안장애", "분리불안장애",
                "틱장애", "뚜렛", "강박장애",
            ],
            replacement: "전문의와 상담하세요",
            exception: nil
        ),

        // ─────────────────────────────────────────
        // 카테고리 2: 약물
        // ─────────────────────────────────────────
        ProhibitedRule(
            category: .medication,
            keywords: [
                // 해열진통제
                "타이레놀", "아세트아미노펜", "이부프로펜", "부루펜",
                "챔프시럽", "맥시부펜",
                // 항생제
                "아목시실린", "세팔로스포린", "페니실린",
                "오구멘틴", "세프디니르", "지스로맥스",
                "항생제 처방", "항생제를 먹",
                // 알레르기/천식
                "항히스타민", "지르텍", "클래리틴",
                "세티리진", "몬테루카스트", "싱귤레어",
                "흡입기", "네뷸라이저",
                // 위장약
                "프로바이오틱스 처방", "락토바실러스",
                "에소메프라졸", "란소프라졸",
                // 피부
                "스테로이드 연고", "히드로코르티손",
                "프로토픽", "엘리델",
                // 수면
                "멜라토닌 처방", "수면제",
                // 비타민/보충제 (직접 권유 금지)
                "비타민D를 먹", "철분제를 먹", "아연을 먹",
                "영양제를 먹", "보충제를 먹",
                // 예방접종 약물 (접종 자체는 허용, 약물명 권유 금지)
                "백신을 맞", "접종을 해",
            ],
            replacement: "소아과 상담을 권합니다",
            exception: nil
        ),

        // ─────────────────────────────────────────
        // 카테고리 3: 의학적 판단
        // ─────────────────────────────────────────
        ProhibitedRule(
            category: .medicalJudgment,
            keywords: [
                // 가능성/의심 표현
                "가능성이 높", "가능성이 있", "~가능성",
                "의심됩니다", "의심이 됩", "의심해볼",
                "로 보입니다", "일 수 있습니다",
                // 담도 관련
                "담도폐쇄증", "담도폐쇄", "담즙정체",
                "선천성 담도", "담관폐쇄",
                // 감염/질환명
                "로타바이러스", "노로바이러스",
                "수족구", "수두", "홍역", "백일해",
                "폐렴", "기관지염", "모세기관지염",
                "중이염", "부비동염", "요로감염",
                "뇌수막염", "뇌막염", "패혈증",
                "크루프", "천식", "아토피",
                // 선천성 질환
                "선천성 심장", "심장 기형", "심실중격결손",
                "선천성 갑상선", "갑상선 기능 저하",
                "페닐케톤뇨증", "PKU",
                "다운증후군", "염색체 이상",
                // 황달/빈혈
                "핵황달", "병적황달", "용혈성",
                "빈혈이 의심", "철결핍성 빈혈",
                // 알레르기 진단
                "식품 알레르기", "아나필락시스",
                "우유 알레르기", "계란 알레르기",
                // 피부질환 진단
                "아토피 피부염", "습진", "두드러기",
                "농가진", "칸디다",
                // 영양/대사
                "탈수", "저혈당", "전해질 불균형",
                "구루병", "영양실조",
                // 정형외과
                "사경", "고관절 이형성", "내반족",
                // 비뇨기
                "요로 감염", "방광 요관 역류",
                // 신경
                "열성 경련", "뇌전증", "간질",
                "영아 연축", "웨스트증후군",
            ],
            replacement: "소아과에서 확인해보세요",
            exception: { sentence in
                // 대변 회색/흰색 관련 긴급 안내는 허용
                let urgentKeywords = ["대변 회색", "대변 흰색", "회색 변", "흰색 변",
                                      "회색빛 변", "하얀 변", "백색변", "회백색"]
                return urgentKeywords.contains(where: { sentence.contains($0) })
            }
        ),

        // ─────────────────────────────────────────
        // 대변 색상 이상 (검은 변/혈변 — 즉각 진료 필요)
        // ─────────────────────────────────────────
        ProhibitedRule(
            category: .medicalJudgment,
            keywords: [
                "검은 대변", "검은변", "흑색변", "흑변",
                "멜레나", "혈변", "피 섞인 변", "피가 섞인 변",
                "빨간 대변", "빨간변", "붉은 대변", "붉은변",
            ],
            replacement: "대변 색상이 비정상적이면 소아과에서 확인해보세요",
            exception: nil
        ),

        // ─────────────────────────────────────────
        // 추가 안전장치: 긴급 상황 오진 방지
        // ─────────────────────────────────────────
        ProhibitedRule(
            category: .medicalJudgment,
            keywords: [
                "괜찮습니다", "걱정하지 마세요", "정상입니다",
                "문제없습니다", "안심하셔도",
            ],
            replacement: "정확한 판단은 소아과 전문의와 상담하세요",
            exception: nil
        ),
    ]

    // MARK: - 금지어 총 개수 (테스트용)

    static var totalProhibitedKeywordCount: Int {
        prohibitedRules.reduce(0) { $0 + $1.keywords.count }
    }
}

// MARK: - AIReport 확장 (가드레일 적용)

extension AIGuardrailService {
    /// AIReport에 가드레일 적용 (summary, keyChanges, checklistItems 모두 필터)
    static func filterReport(_ report: AIReport) -> AIReport {
        AIReport(
            summary: filterOnly(report.summary),
            keyChanges: report.keyChanges.map { filterOnly($0) },
            checklistItems: report.checklistItems.map {
                AIReport.ChecklistItem(question: filterOnly($0.question))
            },
            generatedAt: report.generatedAt
        )
    }
}
