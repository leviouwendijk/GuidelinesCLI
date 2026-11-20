import Guidelines
import GuidelinesSearch
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

        var scrollOffsetByReference: [
            String: Int
        ] = [:]
    }

    private let navigation =
        NavigationState()

    private let searchIndex =
        GuidelineSearchIndex()

    func run() throws {
        let session = try TerminalSession(
            options:
                TerminalSession.Options(
                    useAlternateScreen: true,
                    hideCursor: false,
                    useRawMode: false,
                    restoreOnInterrupt: true,
                    outputStream: .standardError
                )
        )

        defer {
            session.restore()
        }

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

            let result = try chooseResult(
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

            let result = try chooseResult(
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

            if !GuidelineStructuredContentProjection.isEmpty(
                chapter.introduction
            ) {
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

            let result = try chooseResult(
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

        let viewer =
            GuidelineDocumentViewer(
                outputStream: .standardError
            )

        while true {
            let guideline =
                chapter.guidelines[
                    index
                ]

            let hasPrevious =
                index
                > chapter.guidelines.startIndex

            let hasNext =
                index
                < chapter.guidelines.index(
                    before:
                        chapter.guidelines.endIndex
                )

            let result = try viewer.run(
                document: { width in
                    GuidelineTerminalRenderer.render(
                        guideline,
                        in: chapter,
                        width: width
                    )
                },
                initialOffset:
                    navigation.scrollOffsetByReference[
                        guideline.reference
                    ]
                    ?? 0,
                hasPrevious: hasPrevious,
                hasNext: hasNext
            )

            navigation.scrollOffsetByReference[
                guideline.reference
            ] = result.offset

            switch result.action {
            case .previous:
                index -= 1

            case .next:
                index += 1

            case .back:
                return guideline.reference
            }
        }
    }

    private func showOverview(
        _ chapter: GuidelineChapter
    ) throws {
        let reference =
            "chapter:"
            + chapter.reference

        let result = try GuidelineDocumentViewer(
            outputStream: .standardError
        ).run(
            document: { width in
                GuidelineTerminalRenderer.render(
                    chapter,
                    width: width
                )
            },
            initialOffset:
                navigation.scrollOffsetByReference[
                    reference
                ]
                ?? 0,
            hasPrevious: false,
            hasNext: false
        )

        navigation.scrollOffsetByReference[
            reference
        ] = result.offset
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

    private func chooseResult<
        ID: Hashable & Sendable
    >(
        _ title: String,
        choices: [TerminalMenuItem<ID>],
        default defaultID: ID? = nil,
        instructions: String
    ) throws -> TerminalChoiceResult<ID> {
        let width =
            Terminal.size(
                for: .standardError
            ).columns

        let menu =
            TerminalInteractiveMenu<
                TerminalMenuItem<ID>,
                ID
            >(
                items: choices,
                configuration:
                    TerminalInteractiveMenuConfiguration(
                        title: title,
                        instructions: instructions,
                        wrapMode: .wrap,
                        useAlternateScreen: false,
                        hideCursor: true,
                        outputStream: .standardError,
                        presentation: .fullscreen,
                        completionPresentation: .clear,
                        currentRowStyle: .inverse
                    ),
                id: {
                    $0.id
                },
                isEnabled: {
                    $0.isEnabled
                },
                row: {
                    row in

                    row.item.rowContent.render(
                        isCurrent: row.isCurrent,
                        isEnabled: row.isEnabled,
                        theme: .agentic,
                        width: width
                    )
                }
            )

        let result =
            try menu.runRetainingState(
                initialID: defaultID
            )

        switch result {
        case .picked(
            _,
            let id
        ):
            return .picked(
                id
            )

        case .cancelled(
            _,
            let currentID
        ):
            return .cancelled(
                current: currentID
            )
        }
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
