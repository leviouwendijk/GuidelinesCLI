import Fuzzy
import Guidelines
import Matching
import Ranking

struct GuidelineSearchIndex: Sendable {
    enum Target:
        Sendable,
        Hashable
    {
        case chapterOverview
        case guideline(Int)
    }

    struct Entry: Sendable {
        let id: String
        let chapter: GuidelineChapter
        let target: Target
        let title: String
        let summary: String?
        let candidate: BasicMatchCandidate<String>
    }

    private let entries: [Entry]
    private let entriesByID: [String: Entry]

    init(
        chapters: [GuidelineChapter] =
            GuidelineManual.chapters
    ) {
        let entries = chapters.flatMap {
            chapter -> [Entry] in

            var entries: [Entry] = []

            if !chapter.introduction.isEmpty {
                let body = Self.text(
                    chapter.introduction
                )

                let id =
                    "chapter:"
                    + chapter.reference

                entries.append(
                    Entry(
                        id: id,
                        chapter: chapter,
                        target: .chapterOverview,
                        title: chapter.title,
                        summary: "Chapter overview",
                        candidate:
                            BasicMatchCandidate(
                                matchID: id,
                                primaryField:
                                    MatchField(
                                        name: "title",
                                        text: chapter.title,
                                        role: .primary,
                                        weight: 8
                                    ),
                                secondaryFields: [
                                    MatchField(
                                        name: "reference",
                                        text: chapter.reference,
                                        role: .alias,
                                        weight: 7
                                    ),
                                    MatchField(
                                        name: "area",
                                        text: chapter.area.rawValue,
                                        role: .tag,
                                        weight: 2
                                    ),
                                    MatchField(
                                        name: "content",
                                        text: body,
                                        role: .body,
                                        weight: 1
                                    ),
                                ]
                            )
                    )
                )
            }

            entries.append(
                contentsOf:
                    chapter.guidelines
                        .enumerated()
                        .map {
                            index,
                            guideline in

                            let explanation =
                                Self.text(
                                    guideline.explanation
                                )

                            let corpus = [
                                guideline.title,
                                guideline.reference,
                                chapter.title,
                                chapter.reference,
                                chapter.area.rawValue,
                                guideline.summary,
                                explanation,
                            ]
                            .joined(
                                separator: "\n"
                            )

                            let id =
                                "guideline:"
                                + guideline.reference

                            return Entry(
                                id: id,
                                chapter: chapter,
                                target:
                                    .guideline(
                                        index
                                    ),
                                title: guideline.title,
                                summary: guideline.summary,
                                candidate:
                                    BasicMatchCandidate(
                                        matchID: id,
                                        primaryField:
                                            MatchField(
                                                name: "title",
                                                text: guideline.title,
                                                role: .primary,
                                                weight: 8
                                            ),
                                        secondaryFields: [
                                            MatchField(
                                                name: "reference",
                                                text: guideline.reference,
                                                role: .alias,
                                                weight: 7
                                            ),
                                            MatchField(
                                                name: "chapter",
                                                text: chapter.title,
                                                role: .secondary,
                                                weight: 5
                                            ),
                                            MatchField(
                                                name: "summary",
                                                text: guideline.summary,
                                                role: .subtitle,
                                                weight: 4
                                            ),
                                            MatchField(
                                                name: "area",
                                                text: chapter.area.rawValue,
                                                role: .tag,
                                                weight: 2
                                            ),
                                            MatchField(
                                                name: "content",
                                                text: corpus,
                                                role: .body,
                                                weight: 1
                                            ),
                                        ]
                                    )
                            )
                        }
            )

            return entries
        }

        self.entries =
            entries

        self.entriesByID =
            Dictionary(
                uniqueKeysWithValues:
                    entries.map {
                        (
                            $0.id,
                            $0
                        )
                    }
            )
    }

    func search(
        _ rawQuery: String,
        limit: Int = 40
    ) -> [Entry] {
        let query = MatchQuery(
            rawQuery
        )

        guard !query.isEmpty else {
            return []
        }

        let ranker =
            FuzzyRanker<
                BasicMatchCandidate<String>
            >(
                selection:
                    RankingSelectionOptions(
                        limit: limit
                    )
            )

        return ranker
            .rank(
                query: query,
                candidates:
                    entries.map(
                        \.candidate
                    )
            )
            .compactMap {
                entriesByID[
                    $0.value.candidateID
                ]
            }
    }

    private static func text(
        _ blocks: [GuidelineContent.Block]
    ) -> String {
        blocks
            .map(
                text
            )
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "\n"
            )
    }

    private static func text(
        _ block: GuidelineContent.Block
    ) -> String {
        switch block {
        case .paragraph(let content):
            return content

        case .code(
            _,
            let content
        ):
            return content

        case .quote(let content):
            return content

        case .list(
            _,
            let items
        ):
            return items.joined(
                separator: "\n"
            )

        case .example(let example):
            return [
                example.title ?? "",
                text(
                    example.content
                ),
            ]
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "\n"
            )

        case .section(let section):
            return [
                section.title,
                text(
                    section.content
                ),
            ]
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "\n"
            )
        }
    }
}
