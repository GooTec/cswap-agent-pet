enum PetCharacter: String, CaseIterable, Identifiable, Sendable {
    case chiikawa
    case hachiware
    case usagi
    case momonga

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chiikawa: T("치이카와")
        case .hachiware: T("하치와레")
        case .usagi: T("우사기")
        case .momonga: T("모몽가")
        }
    }
}
