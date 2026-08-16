import Guidelines

extension GuidelineArea {
    var terminalTitle: String {
        switch self {
        case .design:
            "Design"

        case .ergonomics:
            "Ergonomics"

        case .structure:
            "Structure"
        }
    }
}
