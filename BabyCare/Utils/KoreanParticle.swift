import Foundation

/// 조사(을/를 · 이/가)를 앞 낱말에 맞춰 고른다.
///
/// 왜 필요한가: 시리 응답을 수유 낱말로만 만들었을 때는 "모유 수유를 기록했어요" 처럼
/// 늘 '를' 이 맞았다. 기록 전 종류로 넓히자 "소변를 기록했어요" 가 나온다 — 받침이 있으면 '을' 이다.
/// 손님이 듣는 말이라 틀리면 바로 어색하다.
///
/// ⚠️ 범위: 이 앱이 시리 응답에 쓰는 낱말(한글 · "…ml" · "…도")에서 맞다.
///    한글 음절도 숫자·기호도 아닌 것으로 끝나면 받침 없음으로 본다.
enum KoreanParticle {
    /// 목적격 — 받침 있으면 "을", 없으면 "를".
    static func object(after word: String) -> String {
        hasFinalConsonant(word) ? "을" : "를"
    }

    /// 주격 — 받침 있으면 "이", 없으면 "가".
    static func subject(after word: String) -> String {
        hasFinalConsonant(word) ? "이" : "가"
    }

    /// 아이 이름과 함께 — "서준이와" / "서아와".
    /// 받침이 있는 이름은 '이' 를 붙여 부르는 것이 자연스럽다(부르는 말과 같은 규칙).
    static func withName(_ name: String) -> String {
        hasFinalConsonant(name) ? "\(name)이와" : "\(name)와"
    }

    /// 마지막 한글 음절에 받침이 있나.
    /// "120ml" 처럼 단위로 끝나면 읽는 말(밀리리터)에 받침이 없으므로 false.
    static func hasFinalConsonant(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if trimmed.lowercased().hasSuffix("ml") { return false }   // 밀리리터

        // 뒤에서부터 첫 한글 음절을 찾는다(")" 같은 기호로 끝나는 경우 대비).
        for scalar in trimmed.unicodeScalars.reversed() {
            guard (0xAC00...0xD7A3).contains(scalar.value) else { continue }
            return (scalar.value - 0xAC00) % 28 != 0
        }
        return false
    }
}
