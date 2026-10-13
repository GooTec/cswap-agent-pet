import Foundation
import Testing
@testable import ChiikawaPet

struct CharacterTests {
    @Test @MainActor func selectionAndWanderingPersistAcrossStoreRecreation() throws {
        let suiteName = "CharacterTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(usageFetching: UsageClient(), preferences: preferences)
        #expect(store.selectedCharacter == .chiikawa)
        #expect(store.wanders)
        store.wanders = false

        for character in PetCharacter.allCases {
            store.selectedCharacter = character
            let reopenedPreferences = try #require(UserDefaults(suiteName: suiteName))
            let restored = UsageStore(usageFetching: UsageClient(), preferences: reopenedPreferences)
            #expect(restored.selectedCharacter == character)
            #expect(!restored.wanders)
        }
    }

    @Test @MainActor func invalidSavedCharacterFallsBackSafely() throws {
        let suiteName = "CharacterTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let invalidCharacters: [Any] = ["removed-character", "", "HACHIWARE", 42]
        for invalid in invalidCharacters {
            preferences.set(invalid, forKey: "petCharacter")
            let store = UsageStore(usageFetching: UsageClient(), preferences: preferences)
            #expect(store.selectedCharacter == .chiikawa)
        }
    }

    @Test(arguments: [90.0, 89.0]) @MainActor
    func selectionPreservesDecodedQuotaAndCryingBoundary(claudeUsedPercent: Double) async throws {
        let suiteName = "CharacterTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let claudeUsage = Data("{\"five_hour\":{\"utilization\":20},\"seven_day_sonnet\":{\"utilization\":\(claudeUsedPercent)}}".utf8)
        let codexUsage = Data(#"{"rate_limit":{"primary_window":{"used_percent":20,"limit_window_seconds":18000}}}"#.utf8)
        let usageFetching = CharacterFixtureUsage(claudeUsage: claudeUsage, codexUsage: codexUsage)
        let store = UsageStore(usageFetching: usageFetching, preferences: preferences)
        await store.refresh()
        let remainingPercent = 100 - claudeUsedPercent
        let expectedMood: PetMood = claudeUsedPercent == 90 ? .crying : .sad
        #expect(store.remainingPercent == remainingPercent)
        #expect(store.mood == expectedMood)
        let readings = store.providers.compactMap(\.reading)
        #expect(readings.count == 2)

        for character in PetCharacter.allCases {
            store.selectedCharacter = character
            #expect(store.remainingPercent == remainingPercent)
            #expect(store.mood == expectedMood)
            for original in readings {
                let current = try #require(store.providers.first { $0.provider == original.provider }?.reading)
                #expect(current.windows == original.windows)
                #expect(current.fetchedAt == original.fetchedAt)
            }
        }
    }
}

private struct CharacterFixtureUsage: UsageFetching {
    let claudeUsage: Data
    let codexUsage: Data

    func fetch(_ provider: UsageProvider, allowKeychainPrompt: Bool) async throws -> UsageReading {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        switch provider {
        case .claude: return try UsageClient.decodeClaude(claudeUsage, now: now)
        case .codex: return try UsageClient.decodeCodex(codexUsage, now: now)
        }
    }
}
