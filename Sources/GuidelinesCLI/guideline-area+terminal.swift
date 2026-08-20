import Guidelines

extension GuidelineArea {
    var terminalTitle: String {
        switch rawValue {
        case "design":
            return "Design"

        case "ergonomics":
            return "Ergonomics"

        case "structure":
            return "Structure"

        case "ai":
            return "AI"

        default:
            return rawValue
        }
    }
}
