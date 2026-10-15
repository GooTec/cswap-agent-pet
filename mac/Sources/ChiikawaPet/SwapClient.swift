import Foundation

// Optional integration with claude-swap (cswap): github.com/realiti4/claude-swap.
// The pet only drives cswap's documented CLI (`--json` for list/switch); it never reads its credential store.

struct SwapAccount: Sendable, Equatable, Identifiable {
    let number: Int
    let email: String
    let alias: String?
    let organizationName: String?
    let isActive: Bool
    let fiveHourRemaining: Double?
    let weeklyRemaining: Double?

    var id: String { email }
    var label: String { alias.flatMap { $0.isEmpty ? nil : $0 } ?? email }
}

struct SwapSnapshot: Sendable, Equatable {
    let accounts: [SwapAccount]
    let autoSwitchEnabled: Bool
    var active: SwapAccount? { accounts.first(where: \.isActive) }
}

enum SwapFailure: Error, LocalizedError, Sendable {
    case notInstalled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "cswap을 찾을 수 없습니다."
        case .failed(let message): "cswap 실행 실패: \(message)"
        }
    }
}

struct SwapClient: Sendable {
    let executable: URL?
    private let home: URL

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
        executable = Self.locate(home: home)
    }

    var isInstalled: Bool { executable != nil }

    private var menubarSettings: URL {
        home.appendingPathComponent(".claude-swap-backup/menubar_settings.json")
    }

    static func locate(home: URL) -> URL? {
        // Finder-launched apps get a minimal PATH, so check the usual install locations directly.
        var candidates = [
            home.appendingPathComponent(".local/bin/cswap").path,
            "/opt/homebrew/bin/cswap",
            "/usr/local/bin/cswap"
        ]
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        candidates += path.split(separator: ":").map { "\($0)/cswap" }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }

    func snapshot() async throws -> SwapSnapshot {
        let output = try await run(["list", "--json"])
        let accounts = try Self.decodeAccounts(output)
        return SwapSnapshot(accounts: accounts, autoSwitchEnabled: autoSwitchEnabled())
    }

    func switchTo(_ number: Int) async throws {
        _ = try await run(["switch", String(number), "--json"], timeout: 60)
    }

    func switchToBest() async throws {
        _ = try await run(["switch", "--strategy", "best", "--json"], timeout: 60)
    }

    func addCurrent() async throws -> String {
        let output = try await run(["add"], timeout: 60)
        return Self.lastLine(output) ?? ""
    }

    func autoSwitchEnabled() -> Bool {
        guard let data = try? Data(contentsOf: menubarSettings),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return settings["auto_switch_enabled"] as? Bool ?? false
    }

    /// Returns false when the cswap menu bar service is not running, so the change waits for its next start.
    func setAutoSwitch(_ enabled: Bool) async throws -> Bool {
        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: menubarSettings),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }
        settings["auto_switch_enabled"] = enabled
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: menubarSettings, options: .atomic)
        } catch {
            throw SwapFailure.failed(error.localizedDescription)
        }
        // The menu bar reads this file only at startup.
        let service = "gui/\(getuid())/com.cswap.menubar"
        let launchctl = URL(fileURLWithPath: "/bin/launchctl")
        guard (try? await Self.execute(launchctl, ["print", service], timeout: 10))?.status == 0 else { return false }
        let restart = try await Self.execute(launchctl, ["kickstart", "-k", service], timeout: 20)
        return restart.status == 0
    }

    nonisolated static func decodeAccounts(_ data: Data) throws -> [SwapAccount] {
        let response: SwapListResponse
        do { response = try JSONDecoder().decode(SwapListResponse.self, from: data) }
        catch { throw SwapFailure.failed("list --json") }
        return response.accounts.compactMap { account in
            guard let email = account.email, !email.isEmpty else { return nil }
            return SwapAccount(
                number: account.number, email: email, alias: account.alias,
                organizationName: account.organizationName, isActive: account.active ?? false,
                fiveHourRemaining: account.usage?.fiveHour?.pct.map { 100 - $0 },
                weeklyRemaining: account.usage?.sevenDay?.pct.map { 100 - $0 }
            )
        }.sorted { $0.number < $1.number }
    }

    private static func lastLine(_ data: Data) -> String? {
        String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.last { !$0.isEmpty }
    }

    private func run(_ arguments: [String], timeout: TimeInterval = 20) async throws -> Data {
        guard let executable else { throw SwapFailure.notInstalled }
        let result = try await Self.execute(executable, arguments, timeout: timeout)
        guard result.status == 0 else {
            let message = Self.lastLine(result.errors) ?? Self.lastLine(result.output) ?? "exit \(result.status)"
            throw SwapFailure.failed(message)
        }
        return result.output
    }

    private static func execute(_ executable: URL, _ arguments: [String], timeout: TimeInterval) async throws
        -> (status: Int32, output: Data, errors: Data) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                var environment = ProcessInfo.processInfo.environment
                environment["NO_COLOR"] = "1"
                environment["PATH"] = [executable.deletingLastPathComponent().path, "/usr/bin", "/bin", environment["PATH"] ?? ""]
                    .joined(separator: ":")
                process.environment = environment
                let output = Pipe()
                let errors = Pipe()
                process.standardOutput = output
                process.standardError = errors
                process.standardInput = FileHandle.nullDevice
                do { try process.run() } catch {
                    continuation.resume(throwing: SwapFailure.failed(error.localizedDescription))
                    return
                }
                let processID = process.processIdentifier
                let watchdog = DispatchWorkItem { kill(processID, SIGTERM) }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
                let errorReader = DispatchGroup()
                nonisolated(unsafe) var errorData = Data()
                errorReader.enter()
                DispatchQueue.global().async {
                    errorData = errors.fileHandleForReading.readDataToEndOfFile()
                    errorReader.leave()
                }
                let outputData = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                errorReader.wait()
                watchdog.cancel()
                continuation.resume(returning: (process.terminationStatus, outputData, errorData))
            }
        }
    }
}

/// Each cswap account owns one pet character, so the pet on screen always shows the active account.
enum AccountCharacters {
    static func assign(_ accounts: [SwapAccount], saved: [String: PetCharacter]) -> [String: PetCharacter] {
        var result = saved
        var used = Set(accounts.compactMap { saved[$0.email] })
        for account in accounts where result[account.email] == nil {
            let free = PetCharacter.allCases.first { !used.contains($0) }
            let character = free ?? PetCharacter.allCases[(account.number - 1) % PetCharacter.allCases.count]
            result[account.email] = character
            used.insert(character)
        }
        return result
    }

    /// Gives `character` to `email`; an account that already had it takes `email`'s old character.
    static func reassign(_ email: String, to character: PetCharacter, in map: [String: PetCharacter], accounts: [SwapAccount]) -> [String: PetCharacter] {
        var result = map
        let previous = result[email]
        for account in accounts where account.email != email && result[account.email] == character {
            result[account.email] = previous
        }
        result[email] = character
        return result
    }

    static func account(for character: PetCharacter, in map: [String: PetCharacter], accounts: [SwapAccount]) -> SwapAccount? {
        accounts.first { map[$0.email] == character }
    }
}

private struct SwapListResponse: Decodable {
    let accounts: [Account]

    struct Account: Decodable {
        let number: Int
        let email: String?
        let alias: String?
        let organizationName: String?
        let active: Bool?
        let usage: Usage?
    }

    struct Usage: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?
    }

    struct Window: Decodable {
        let pct: Double?
    }
}
