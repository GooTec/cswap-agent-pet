import Combine
import Foundation

struct ProviderDisplay: Sendable {
    let provider: UsageProvider
    var reading: UsageReading?
    var error: String?
}

@MainActor
final class UsageStore: ObservableObject {
    static let defaultPetScale = 0.65
    static let petScaleRange = 0.4...1.2
    @Published private(set) var providers: [ProviderDisplay] = UsageProvider.allCases.map {
        ProviderDisplay(provider: $0)
    }
    @Published private(set) var isRefreshing = false
    @Published var language: AppLanguage {
        didSet { preferences.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published var wanders: Bool {
        didSet { preferences.set(wanders, forKey: "wanders") }
    }
    @Published var selectedCharacter: PetCharacter {
        didSet { preferences.set(selectedCharacter.rawValue, forKey: "petCharacter") }
    }
    @Published private(set) var petScale: Double
    @Published var isPetVisible: Bool {
        didSet { preferences.set(isPetVisible, forKey: "petVisible") }
    }
    @Published private(set) var swap: SwapSnapshot?
    @Published private(set) var accountCharacters: [String: PetCharacter] = [:]
    @Published private(set) var isSwitchingAccount = false
    @Published private(set) var swapMessage: String?
    let previewPercent: Double?
    private let usageFetching: any UsageFetching
    private let swapClient: SwapClient?
    private let preferences: UserDefaults
    private var isLoadingSwap = false
    private var swapMessageIsListError = false

    init(usageFetching: any UsageFetching, swapClient: SwapClient? = nil, previewPercent: Double? = nil, preferences: UserDefaults = .standard) {
        self.usageFetching = usageFetching
        self.swapClient = previewPercent == nil && swapClient?.isInstalled == true ? swapClient : nil
        self.previewPercent = previewPercent
        self.preferences = preferences
        language = AppLanguage(rawValue: preferences.string(forKey: "appLanguage") ?? "en") ?? .english
        wanders = preferences.object(forKey: "wanders") as? Bool ?? true
        let savedCharacter = preferences.string(forKey: "petCharacter") ?? ""
        selectedCharacter = PetCharacter(rawValue: savedCharacter) ?? .chiikawa
        let savedScale = preferences.object(forKey: "petScale") as? Double
        if let savedScale, savedScale.isFinite, Self.petScaleRange.contains(savedScale) {
            petScale = savedScale
        } else {
            petScale = Self.defaultPetScale
        }
        isPetVisible = preferences.object(forKey: "petVisible") as? Bool ?? true
        let savedCharacters = preferences.dictionary(forKey: "accountCharacters") as? [String: String] ?? [:]
        accountCharacters = savedCharacters.compactMapValues { PetCharacter(rawValue: $0) }
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

    func setPetScale(_ scale: Double) {
        guard scale.isFinite else { return }
        petScale = min(max(scale, Self.petScaleRange.lowerBound), Self.petScaleRange.upperBound)
        preferences.set(petScale, forKey: "petScale")
    }

    var menuBarTitle: String {
        let claude = menuBarRemaining(for: .claude)
        let codex = menuBarRemaining(for: .codex)
        return "Claude \(claude) · Codex \(codex)"
    }

    var menuBarPresentation: MenuBarPresentation {
        let claude = providers.first { $0.provider == .claude && $0.error == nil }?.reading
        let codex = providers.first { $0.provider == .codex && $0.error == nil }?.reading
        let primary = claude?.windows.first?.remainingPercent
        let secondary = claude.flatMap { $0.windows.count > 1 ? $0.windows[1].remainingPercent : nil }
        return MenuBarPresentation(
            character: selectedCharacter, mood: mood,
            claudePrimary: primary, claudeSecondary: secondary, codex: codex?.remainingPercent
        )
    }

    private func menuBarRemaining(for provider: UsageProvider) -> String {
        guard let display = providers.first(where: { $0.provider == provider }),
              display.error == nil, let percent = display.reading?.remainingPercent else { return "—" }
        return "\(Int(percent.rounded(.down)))%"
    }

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

    // MARK: - cswap accounts

    var usesSwap: Bool { swapClient != nil }

    func character(for account: SwapAccount) -> PetCharacter? { accountCharacters[account.email] }

    func account(for character: PetCharacter) -> SwapAccount? {
        guard let swap else { return nil }
        return AccountCharacters.account(for: character, in: accountCharacters, accounts: swap.accounts)
    }

    func refreshSwap() async {
        guard let swapClient, !isLoadingSwap else { return }
        isLoadingSwap = true
        defer { isLoadingSwap = false }
        let previousActive = swap?.active?.email
        do {
            let snapshot = try await swapClient.snapshot()
            if swapMessageIsListError { swapMessage = nil; swapMessageIsListError = false }
            swap = snapshot
            var saved = accountCharacters
            // Keep the pet the user already sees on the active account when it has no character yet.
            if let active = snapshot.active, saved[active.email] == nil,
               !snapshot.accounts.contains(where: { saved[$0.email] == selectedCharacter }) {
                saved[active.email] = selectedCharacter
            }
            saveAccountCharacters(AccountCharacters.assign(snapshot.accounts, saved: saved))
            if let active = snapshot.active, let character = accountCharacters[active.email], character != selectedCharacter {
                selectedCharacter = character
            }
            if previousActive != nil, snapshot.active?.email != previousActive {
                await refresh()
            }
        } catch {
            swapMessage = error.localizedDescription
            swapMessageIsListError = true
        }
    }

    /// Picking a character switches to the account that owns it; an unowned character goes to the active account.
    func selectCharacter(_ character: PetCharacter) {
        guard let swap, let active = swap.active else {
            selectedCharacter = character
            return
        }
        if let owner = account(for: character), owner.email != active.email {
            Task { await switchAccount(to: owner) }
        } else {
            assign(character, to: active)
        }
    }

    func assign(_ character: PetCharacter, to account: SwapAccount) {
        guard let swap else { return }
        saveAccountCharacters(AccountCharacters.reassign(account.email, to: character, in: accountCharacters, accounts: swap.accounts))
        if let active = swap.active, let activeCharacter = accountCharacters[active.email] {
            selectedCharacter = activeCharacter
        }
    }

    func switchAccount(to account: SwapAccount) async {
        await runSwapAction { client in
            try await client.switchTo(account.number)
            return T("\(account.label) 계정으로 전환했어요.")
        }
    }

    func switchToBestAccount() async {
        await runSwapAction { client in
            try await client.switchToBest()
            return nil
        }
    }

    func addCurrentAccount() async {
        await runSwapAction { client in try await client.addCurrent() }
    }

    func setAutoSwitch(_ enabled: Bool) async {
        await runSwapAction { client in
            let applied = try await client.setAutoSwitch(enabled)
            return applied ? nil : T("자동 전환 설정은 cswap 메뉴바가 다시 시작될 때 적용돼요.")
        }
    }

    private func runSwapAction(_ action: @escaping @Sendable (SwapClient) async throws -> String?) async {
        guard let swapClient, !isSwitchingAccount else { return }
        isSwitchingAccount = true
        swapMessage = nil
        swapMessageIsListError = false
        do {
            swapMessage = try await action(swapClient)
        } catch {
            swapMessage = error.localizedDescription
        }
        isSwitchingAccount = false
        await refreshSwap()
    }

    private func saveAccountCharacters(_ characters: [String: PetCharacter]) {
        guard characters != accountCharacters else { return }
        accountCharacters = characters
        preferences.set(characters.mapValues(\.rawValue), forKey: "accountCharacters")
    }
}
