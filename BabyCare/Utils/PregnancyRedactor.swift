import Foundation

/// 임신(pregnancy) 민감 건강정보가 Sentry 크래시 리포트로 유출되지 않도록 redact 하는 순수 로직.
///
/// Sentry SDK 에 의존하지 않으므로 DEBUG 빌드에서 단위 테스트 가능하다 (실제 SDK 어댑터는
/// `BabyCareApp` 의 `#if !DEBUG` `redactPregnancyEvent` / `redactPregnancyBreadcrumb` 가
/// 이 타입에 위임한다). safety.md: 임신 데이터를 Firebase Analytics / Crashlytics / Sentry 등
/// 외부로 전송 금지 — message 뿐 아니라 exceptions / extra / breadcrumb.data 까지 방어.
enum PregnancyRedactor {

    /// 키워드가 감지된 문자열 값을 대체할 placeholder.
    static let placeholder = "[redacted: pregnancy context]"

    /// 임신 맥락을 나타내는 키워드(소문자, en/ko). 부분 일치(substring)로 검사.
    static let keywords = ["pregnancy", "임신", "kick", "태동", "edd", "lmp", "prenatal"]

    /// 문자열에 임신 키워드가 (대소문자 무시) 포함되는지.
    static func containsKeyword(_ text: String) -> Bool {
        let lower = text.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    /// dict(또는 중첩 dict / array) 안에 임신 키워드가 (키 또는 문자열 값에) 하나라도 있는지.
    /// breadcrumb 통째 drop 판정용.
    static func containsKeyword(inDict dict: [String: Any]) -> Bool {
        for (key, value) in dict {
            if containsKeyword(key) { return true }
            if valueContainsKeyword(value) { return true }
        }
        return false
    }

    /// dict 값을 재귀적으로 스크럽: 키워드 포함 문자열을 placeholder 로 치환.
    /// 키 자체가 키워드면 값을 placeholder 로(키 이름은 보존 → 구조 유지).
    /// 비-문자열 스칼라(숫자 / 불리언 등)는 보존한다.
    static func scrub(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        result.reserveCapacity(dict.count)
        for (key, value) in dict {
            result[key] = containsKeyword(key) ? placeholder : scrubValue(value)
        }
        return result
    }

    /// 임의 값(String / 중첩 dict / array)을 재귀 스크럽.
    static func scrubValue(_ value: Any) -> Any {
        switch value {
        case let string as String:
            return containsKeyword(string) ? placeholder : string
        case let dict as [String: Any]:
            return scrub(dict)
        case let array as [Any]:
            return array.map(scrubValue)
        default:
            return value
        }
    }

    private static func valueContainsKeyword(_ value: Any) -> Bool {
        switch value {
        case let string as String:
            return containsKeyword(string)
        case let dict as [String: Any]:
            return containsKeyword(inDict: dict)
        case let array as [Any]:
            return array.contains(where: valueContainsKeyword)
        default:
            return false
        }
    }
}
