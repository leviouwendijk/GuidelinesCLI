import Guidelines
import Terminal

enum GuidelineTerminalRenderer {
    static func render(
        _ guideline: Guideline
    ) -> String {
        let width = contentWidth()

        let header = TerminalDetailDocument(
            title: guideline.title,
            sections: [
                .init(
                    title: "Guideline",
                    items: [
                        .field(
                            label: "Reference",
                            value: guideline.reference
                        ),
                        .field(
                            label: "Area",
                            value: guideline.area.terminalTitle
                        ),
                    ]
                ),
            ],
            theme: .agentic,
            layout: .agentic
        )

        let summary = [
            "Summary"
                .ansi(
                    .brightBlack,
                    .bold
                ),
            wrap(
                guideline.summary,
                width: width
            ),
        ]
        .joined(
            separator: "\n"
        )

        let explanation = render(
            guideline.explanation,
            width: width
        )

        return [
            header.render(
                width: width
            ),
            summary,
            divider(
                width: width
            ),
            explanation,
            divider(
                width: width
            ),
        ]
        .filter {
            !$0.isEmpty
        }
        .joined(
            separator: "\n\n"
        )
    }

    static func render(
        _ chapter: GuidelineChapter
    ) -> String {
        let width = contentWidth()

        let body = chapter.introduction.isEmpty
            ? "This chapter has no separate overview."
            : render(
                chapter.introduction,
                width: width
            )

        return TerminalDetailDocument(
            title: chapter.title,
            sections: [
                .init(
                    title: "Chapter",
                    items: [
                        .field(
                            label: "Reference",
                            value: chapter.reference
                        ),
                        .field(
                            label: "Area",
                            value: chapter.area.terminalTitle
                        ),
                        .field(
                            label: "Guidelines",
                            value: "\(chapter.guidelines.count)"
                        ),
                        .body(
                            body
                        ),
                    ]
                ),
            ],
            theme: .agentic,
            layout: .agentic
        )
        .render(
            width: width
        )
    }

    static func render(
        _ blocks: [GuidelineContent.Block],
        width: Int
    ) -> String {
        blocks
            .map {
                render(
                    $0,
                    width: width
                )
            }
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator: "\n\n"
            )
    }

    private static func render(
        _ block: GuidelineContent.Block,
        width: Int
    ) -> String {
        switch block {
        case .paragraph(let content):
            return wrap(
                content,
                width: width
            )

        case .code(
            let language,
            let content
        ):
            let label: String

            if let language {
                label = "[\(language)]"
                    .ansi(
                        .brightBlack
                    )
                    + "\n"
            } else {
                label = ""
            }

            let code = content
                .split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                )
                .map {
                    "    \($0)"
                }
                .joined(
                    separator: "\n"
                )
                .ansi(
                    .dim
                )

            return label + code

        case .quote(let content):
            return TerminalTextWrap
                .lines(
                    content,
                    width: max(
                        1,
                        width - 4
                    )
                )
                .map {
                    "│ \($0)"
                }
                .joined(
                    separator: "\n"
                )
                .ansi(
                    .italic
                )

        case .list(
            let style,
            let items
        ):
            return renderList(
                style: style,
                items: items,
                width: width
            )

        case .example(let example):
            let title = example.title
                .map {
                    "Example: \($0)"
                }
                ?? "Example"

            return title
                .ansi(
                    .bold,
                    .brightCyan
                )
                + "\n"
                + indent(
                    render(
                        example.content,
                        width: max(
                            1,
                            width - 4
                        )
                    ),
                    by: 4
                )

        case .section(let section):
            return section.title
                .ansi(
                    .bold,
                    .brightCyan
                )
                + "\n\n"
                + render(
                    section.content,
                    width: width
                )
        }
    }

    private static func renderList(
        style: GuidelineContent.ListStyle,
        items: [String],
        width: Int
    ) -> String {
        items
            .enumerated()
            .map {
                index,
                item in

                let marker: String

                switch style {
                case .unordered:
                    marker = "- "

                case .ordered:
                    marker = "\(index + 1). "
                }

                let wrapped = TerminalTextWrap.lines(
                    item,
                    width: max(
                        1,
                        width - marker.count
                    )
                )

                guard let first = wrapped.first else {
                    return marker
                }

                let continuation = String(
                    repeating: " ",
                    count: marker.count
                )

                return (
                    [marker + first]
                    + wrapped
                        .dropFirst()
                        .map {
                            continuation + $0
                        }
                )
                .joined(
                    separator: "\n"
                )
            }
            .joined(
                separator: "\n"
            )
    }

    private static func divider(
        width: Int
    ) -> String {
        String(
            repeating: "─",
            count: max(
                1,
                min(
                    width,
                    72
                )
            )
        )
        .ansi(
            .brightBlack
        )
    }

    private static func wrap(
        _ content: String,
        width: Int
    ) -> String {
        TerminalTextWrap
            .lines(
                content,
                width: width
            )
            .joined(
                separator: "\n"
            )
    }

    private static func indent(
        _ content: String,
        by amount: Int
    ) -> String {
        let prefix = String(
            repeating: " ",
            count: amount
        )

        return content
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map {
                $0.isEmpty
                    ? ""
                    : prefix + $0
            }
            .joined(
                separator: "\n"
            )
    }

    private static func contentWidth() -> Int {
        max(
            40,
            Terminal.size(
                for: .standardError
            ).columns - 2
        )
    }
}
