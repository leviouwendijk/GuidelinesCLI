import Guidelines
import Terminal

struct GuidelinesManualBrowser {
    private enum RootAction:
        Hashable,
        Sendable
    {
        case search
        case area(GuidelineArea)
    }

    private final class NavigationState {
        var rootAction: RootAction?
        var area: GuidelineArea?
        var searchResultID: String?
        var searchQuery: String = ""

        var chapterByArea: [
            GuidelineArea: String
        ] = [:]

        var entryByChapter: [
            String: String
        ] = [:]
    }

    private let navigation =
        NavigationState()

    private let searchIndex =
        GuidelineSearchIndex()

    private enum PageAction:
        Hashable,
        Sendable
    {
        case previous
        case chapter
        case next
    }

    private enum ChapterAction:
        Hashable,
        Sendable
    {
        case back
    }

    func run() throws {
        while true {
            clearPage()

            var choices: [
                TerminalMenuItem<RootAction>
            ] = [
                .init(
                    id: .search,
                    title: "Search manual",
                    caption:
                        "Fuzzy-ranked search across chapters, "
                        + "guidelines, summaries, references, and content."
                ),
            ]

            choices.append(
                contentsOf:
                    GuidelineArea.allCases.map {
                        area in

                        let chapters = chapters(
                            in: area
                        )

                        let guidelineCount = chapters
                            .reduce(
                                0
                            ) {
                                partial,
                                chapter in

                                partial
                                    + chapter.guidelines.count
                            }

                        return TerminalMenuItem(
                            id: RootAction.area(
                                area
                            ),
                            title: area.terminalTitle,
                            caption:
                                "\(chapters.count) chapters, "
                                + "\(guidelineCount) guidelines"
                        )
                    }
            )

            let result = try Terminal.chooseResult(
                "Guidelines",
                choices: choices,
                default:
                    navigation.rootAction
                    ?? navigation.area.map(
                        RootAction.area
                    )
                    ?? .search,
                instructions:
                    "Enter opens. "
                    + "Search covers the complete manual. "
                    + "q/Esc exits."
            )

            navigation.rootAction =
                result.currentID
                ?? navigation.rootAction

            guard case .picked(
                let action
            ) = result else {
                return
            }

            navigation.rootAction =
                action

            switch action {
            case .search:
                try search()

            case .area(let area):
                navigation.area =
                    area

                try browse(
                    area
                )
            }
        }
    }

    private func search() throws {
        let picker = GuidelineLiveSearch(
            searchIndex: searchIndex,
            configuration: .init(
                debounceMilliseconds: 50,
                maximumVisibleResults: 10,
                outputStream: .standardError
            )
        )

        while true {
            let result = try picker.run(
                initialQuery:
                    navigation.searchQuery,
                initialCurrentID:
                    navigation.searchResultID
            )

            switch result {
            case .cancelled(
                let query,
                let currentID
            ):
                navigation.searchQuery =
                    query

                navigation.searchResultID =
                    currentID

                return

            case .picked(
                let entry,
                let query
            ):
                navigation.searchQuery =
                    query

                navigation.searchResultID =
                    entry.id

                switch entry.target {
                case .chapterOverview:
                    try showOverview(
                        entry.chapter
                    )

                case .guideline(
                    let index
                ):
                    _ = try read(
                        entry.chapter,
                        startingAt: index
                    )
                }
            }
        }
    }

    private func browse(
        _ area: GuidelineArea
    ) throws {
        let chapters = chapters(
            in: area
        )

        while true {
            clearPage()

            let choices = chapters.map {
                chapter in

                TerminalMenuItem(
                    id: chapter.reference,
                    title: chapter.title,
                    caption: chapterCaption(
                        chapter
                    )
                )
            }

            let result = try Terminal.chooseResult(
                area.terminalTitle,
                choices: choices,
                default:
                    navigation.chapterByArea[
                        area
                    ],
                instructions:
                    "Enter opens a chapter. q/Esc goes back."
            )

            if let current =
                result.currentID
            {
                navigation.chapterByArea[
                    area
                ] = current
            }

            guard case .picked(
                let reference
            ) = result else {
                return
            }

            navigation.chapterByArea[
                area
            ] = reference

            guard let chapter = chapters.first(
                where: {
                    $0.reference == reference
                }
            ) else {
                continue
            }

            try browse(
                chapter
            )
        }
    }

    private func browse(
        _ chapter: GuidelineChapter
    ) throws {
        while true {
            clearPage()

            var choices: [
                TerminalMenuItem<String>
            ] = []

            if !chapter.introduction.isEmpty {
                choices.append(
                    .init(
                        id: chapterOverviewID,
                        title: "Chapter overview",
                        caption:
                            "Read the chapter-level context and overview."
                    )
                )
            }

            choices.append(
                contentsOf:
                    chapter.guidelines.map {
                        guideline in

                        .init(
                            id: guideline.reference,
                            title: guideline.title,
                            caption: oneLine(
                                guideline.summary
                            )
                        )
                    }
            )

            guard !choices.isEmpty else {
                return
            }

            let result = try Terminal.chooseResult(
                chapter.title,
                choices: choices,
                default:
                    navigation.entryByChapter[
                        chapter.reference
                    ],
                instructions:
                    "Enter opens an entry. q/Esc goes back."
            )

            if let current =
                result.currentID
            {
                navigation.entryByChapter[
                    chapter.reference
                ] = current
            }

            guard case .picked(
                let selection
            ) = result else {
                return
            }

            navigation.entryByChapter[
                chapter.reference
            ] = selection

            if selection == chapterOverviewID {
                try showOverview(
                    chapter
                )

                continue
            }

            guard let index = chapter.guidelines.firstIndex(
                where: {
                    $0.reference == selection
                }
            ) else {
                continue
            }

            let finalReference = try read(
                chapter,
                startingAt: index
            )

            navigation.entryByChapter[
                chapter.reference
            ] = finalReference
        }
    }

    private func read(
        _ chapter: GuidelineChapter,
        startingAt initialIndex: Int
    ) throws -> String {
        var index = initialIndex

        while true {
            clearPage()

            let guideline = chapter.guidelines[
                index
            ]

            Terminal.write(
                GuidelineTerminalRenderer.render(
                    guideline
                )
                + "\n",
                to: .standardError
            )

            let hasPrevious =
                index > chapter.guidelines.startIndex

            let hasNext =
                index
                < chapter.guidelines.index(
                    before:
                        chapter.guidelines.endIndex
                )

            let choices = [
                TerminalMenuItem(
                    id: PageAction.previous,
                    title: "Previous",
                    caption: hasPrevious
                        ? chapter.guidelines[
                            index - 1
                        ].title
                        : nil,
                    isEnabled: hasPrevious
                ),
                TerminalMenuItem(
                    id: PageAction.chapter,
                    title: "Back to chapter",
                    caption: chapter.title
                ),
                TerminalMenuItem(
                    id: PageAction.next,
                    title: "Next",
                    caption: hasNext
                        ? chapter.guidelines[
                            index + 1
                        ].title
                        : nil,
                    isEnabled: hasNext
                ),
            ]

            let defaultAction: PageAction =
                hasNext
                ? .next
                : .chapter

            guard let action = try Terminal.choose(
                "Navigate",
                choices: choices,
                default: defaultAction,
                instructions:
                    "Enter follows the selected action. "
                    + "q/Esc returns to the chapter."
            ) else {
                return guideline.reference
            }

            switch action {
            case .previous:
                index -= 1

            case .chapter:
                return guideline.reference

            case .next:
                index += 1
            }
        }
    }

    private func showOverview(
        _ chapter: GuidelineChapter
    ) throws {
        clearPage()

        Terminal.write(
            GuidelineTerminalRenderer.render(
                chapter
            )
            + "\n",
            to: .standardError
        )

        _ = try Terminal.choose(
            "Navigate",
            choices: [
                TerminalMenuItem(
                    id: ChapterAction.back,
                    title: "Back to chapter",
                    caption: chapter.title
                ),
            ],
            default: .back,
            instructions:
                "Enter or q/Esc returns to the chapter."
        )
    }

    private func chapters(
        in area: GuidelineArea
    ) -> [GuidelineChapter] {
        GuidelineManual.chapters.filter {
            $0.area == area
        }
    }

    private func chapterCaption(
        _ chapter: GuidelineChapter
    ) -> String {
        if chapter.guidelines.isEmpty {
            return "Overview"
        }

        if chapter.guidelines.count == 1 {
            return "1 guideline"
        }

        return "\(chapter.guidelines.count) guidelines"
    }

    private func oneLine(
        _ content: String
    ) -> String {
        content
            .split(
                whereSeparator: {
                    $0.isWhitespace
                }
            )
            .joined(
                separator: " "
            )
    }

    private func clearPage() {
        Terminal.clearScreen()

        Terminal.moveCursor(
            line: 1,
            column: 1
        )
    }

    private var chapterOverviewID: String {
        "__chapter_overview__"
    }
}
