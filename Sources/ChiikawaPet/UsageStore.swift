import Combine
import Foundation

struct ProviderDisplay: Sendable {
    let provider: UsageProvider
    var reading: UsageReading?
    var error: String?
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var providers: [ProviderDisplay] = UsageProvider.allCases.map {
        ProviderDisplay(provider: $0)
    }
    @Published private(set) var isRefreshing = false
    @Published var wanders: Bool {
        didSet { preferences.set(wanders, forKey: "wanders") }
    }
    @Published var selectedCharacter: PetCharacter {
        didSet { preferences.set(selectedCharacter.rawValue, forKey: "petCharacter") }
    }
    let previewPercent: Double?
    private let usageFetching: any UsageFetching
    private let preferences: UserDefaults

    init(usageFetching: any UsageFetching, previewPercent: Double? = nil, preferences: UserDefaults = .standard) {
        self.usageFetching = usageFetching
        self.previewPercent = previewPercent
        self.preferences = preferences
        wanders = preferences.object(forKey: "wanders") as? Bool ?? true
        let savedCharacter = preferences.string(forKey: "petCharacter") ?? ""
        selectedCharacter = PetCharacter(rawValue: savedCharacter) ?? .chiikawa
        if let previewPercent {
            for index in providers.indices {
                let window = try! QuotaWindow(title: "5시간", usedPercent: 100 - previewPercent, resetsAt: nil)
                providers[index].reading = UsageReading(provider: providers[index].provider, windows: [window], fetchedAt: .now)
            }
        }
    }

    var remainingPercent: Double? {
        var lowest: Double?
        for provider in providers where provider.error == nil {
            guard let percent = provider.reading?.remainingPercent else { continue }
            lowest = min(lowest ?? percent, percent)
        }
        return lowest
    }

    var mood: PetMood { .forRemaining(remainingPercent) }

    func refresh(allowKeychainPrompt: Bool = false) async {
        guard !isRefreshing, previewPercent == nil else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: ProviderDisplay.self) { group in
            for provider in UsageProvider.allCases {
                let usageFetching = self.usageFetching
                group.addTask {
                    do {
                        let reading = try await usageFetching.fetch(provider, allowKeychainPrompt: allowKeychainPrompt)
                        return ProviderDisplay(provider: provider, reading: reading)
                    } catch {
                        return ProviderDisplay(provider: provider, error: error.localizedDescription)
                    }
                }
            }
            for await display in group {
                guard let index = providers.firstIndex(where: { $0.provider == display.provider }) else { continue }
                if display.error != nil {
                    providers[index].error = display.error
                } else {
                    providers[index] = display
                }
            }
        }
    }
}
