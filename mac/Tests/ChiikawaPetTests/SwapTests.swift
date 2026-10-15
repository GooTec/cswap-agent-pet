import Foundation
import Testing
@testable import ChiikawaPet

struct SwapTests {
    private func account(_ number: Int, _ email: String, active: Bool = false) -> SwapAccount {
        SwapAccount(number: number, email: email, alias: nil, organizationName: nil, isActive: active,
                    fiveHourRemaining: nil, weeklyRemaining: nil)
    }

    @Test func decodesListJSON() throws {
        let data = Data(#"{"schemaVersion":1,"activeAccountNumber":2,"accounts":[{"number":3,"email":"b@example.com","alias":"work","active":false,"usage":{"fiveHour":{"pct":5.0},"sevenDay":{"pct":91.0}}},{"number":2,"email":"a@example.com","organizationName":"A","active":true,"usage":{"fiveHour":{"pct":10.0}}},{"number":4,"email":null}]}"#.utf8)
        let accounts = try SwapClient.decodeAccounts(data)
        #expect(accounts.map(\.number) == [2, 3])
        #expect(accounts[0].isActive && accounts[0].fiveHourRemaining == 90 && accounts[0].weeklyRemaining == nil)
        #expect(accounts[1].label == "work" && accounts[1].weeklyRemaining == 9)
    }

    @Test func rejectsMalformedListJSON() {
        #expect(throws: SwapFailure.self) { try SwapClient.decodeAccounts(Data("not json".utf8)) }
    }

    @Test func assignsFreeCharactersAndKeepsSaved() {
        let accounts = [account(1, "a"), account(2, "b"), account(3, "c")]
        let map = AccountCharacters.assign(accounts, saved: ["b": .chiikawa])
        #expect(map == ["a": .hachiware, "b": .chiikawa, "c": .usagi])
    }

    @Test func reusesCharactersBeyondFourAccounts() {
        let accounts = (1...5).map { account($0, "\($0)") }
        let map = AccountCharacters.assign(accounts, saved: [:])
        #expect(map["5"] == .chiikawa)
    }

    @Test func reassignSwapsWithPreviousOwner() {
        let accounts = [account(1, "a"), account(2, "b")]
        let map = AccountCharacters.reassign("a", to: .hachiware, in: ["a": .chiikawa, "b": .hachiware], accounts: accounts)
        #expect(map == ["a": .hachiware, "b": .chiikawa])
        #expect(AccountCharacters.account(for: .chiikawa, in: map, accounts: accounts)?.email == "b")
    }
}
