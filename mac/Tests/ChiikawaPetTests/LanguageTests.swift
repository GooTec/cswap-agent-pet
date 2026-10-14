import Foundation
import Testing
@testable import ChiikawaPet

struct LanguageTests {
    @Test @MainActor func languageDefaultsAndPersists() throws {
        let suite = "LanguageTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let store = UsageStore(usageFetching: UsageClient(), preferences: preferences)
        #expect(store.language == .english)
        store.language = .korean
        #expect(UsageStore(usageFetching: UsageClient(), preferences: preferences).language == .korean)
        preferences.set("invalid", forKey: "appLanguage")
        #expect(UsageStore(usageFetching: UsageClient(), preferences: preferences).language == .english)
    }

    @Test func allLabelsAndTemplatesTranslate() {
        for (korean, english) in EnglishText.words {
            #expect(EnglishText.translate(korean) == english)
        }
        #expect(EnglishText.translate("치이카와의 에너지") == "Chiikawa’s energy")
        #expect(EnglishText.translate("5시간") == "5 hours")
        #expect(EnglishText.translate("2일 한도") == "2-day limit")
        #expect(EnglishText.translate("12:30 초기화") == "Resets 12:30")
        #expect(EnglishText.translate("사용량 서버 오류 (HTTP 429). 나중에 새로고침하세요.") == "Usage server error (HTTP 429). Refresh later.")
        #expect(EnglishText.translate("12:30 조회 · 이전 데이터") == "Fetched 12:30 · previous data")
        #expect(EnglishText.translate("unknown system error") == "unknown system error")
    }
}
