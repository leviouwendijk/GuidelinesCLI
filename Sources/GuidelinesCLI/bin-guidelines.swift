import Guidelines
import Terminal

@main
struct GuidelinesCLI {
    static func main() throws {
        try GuidelinesManualBrowser().run()
    }
}
