enum PetCharacter: String, CaseIterable, Identifiable, Sendable {
    case chiikawa
    case hachiware
    case usagi

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chiikawa: "치이카와"
        case .hachiware: "하치와레"
        case .usagi: "우사기"
        }
    }
}
