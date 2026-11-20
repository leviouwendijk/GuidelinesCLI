import Guidelines
import GuidelinesSearch
import Terminal
import TerminalStructuredContent

enum GuidelineTerminalRenderer {
    static func render(
        _ guideline: Guideline,
        in chapter: GuidelineChapter,
        width: Int
    ) -> String {
        let width = max(
            1,
            width
        )

        let header = renderHeader(
            title: guideline.title,
            context:
                chapter.area.terminalTitle
                + " · "
                + chapter.title,
            reference: guideline.reference,
            width: width
        )

        let summary = [
            "SUMMARY"
                .ansi(
                    .brightBlack,
                    .bold
                ),
            indent(
                wrap(
                    guideline.summary,
                    width: max(
                        1,
                        width - 2
                    )
                ),
                by: 2
            ),
        ]
        .joined(
            separator: "\n"
        )

        let explanation = contentRenderer.render(
            guideline.explanation,
            columns: width
        )

        return [
            header,
            summary,
            divider(
                width: width
            ),
            explanation,
        ]
        .filter {
            !$0.isEmpty
        }
        .joined(
            separator: "\n\n"
        )
    }

    static func render(
        _ chapter: GuidelineChapter,
        width: Int
    ) -> String {
        let width = max(
            1,
            width
        )

        let header = renderHeader(
            title: chapter.title,
            context:
                chapter.area.terminalTitle
                + " · Chapter overview",
            reference: chapter.reference,
            detail:
                guidelineCountDescription(
                    chapter.guidelines.count
                ),
            width: width
        )

        let body = GuidelineStructuredContentProjection.isEmpty(
            chapter.introduction
        )
            ? "This chapter has no separate overview."
            : contentRenderer.render(
                chapter.introduction,
                columns: width
            )

        return [
            header,
            divider(
                width: width
            ),
            body,
        ]
        .filter {
            !$0.isEmpty
        }
        .joined(
            separator: "\n\n"
        )
    }

    private static let contentRenderer: TerminalStructuredContent.Renderer = {
        var format = TerminalStructuredContent.Format.minimal

        format.block.group.roles[
            GuidelineContent.Role.example.structuredContentRole
        ] = .init(
            titlePrefix: "Example",
            titleStyle: .init(
                .bold,
                .brightBlack
            ),
            contentIndent: 4,
            spacing: 0
        )

        return TerminalStructuredContent.Renderer(
            format: format
        )
    }()

    private static func renderHeader(
        title: String,
        context: String,
        reference: String,
        detail: String? = nil,
        width: Int
    ) -> String {
        var lines = [
            styledLines(
                wrap(
                    title,
                    width: width
                ),
                style: .init(
                    .bold,
                    .brightCyan
                )
            ),
            "",
            styledLines(
                wrap(
                    context,
                    width: width
                ),
                style: .init(
                    .brightBlack,
                    .bold
                )
            ),
            styledLines(
                wrap(
                    reference,
                    width: width
                ),
                style: .init(
                    .brightBlack
                )
            ),
        ]

        if let detail,
           !detail.isEmpty {
            lines.append(
                styledLines(
                    wrap(
                        detail,
                        width: width
                    ),
                    style: .init(
                        .brightBlack
                    )
                )
            )
        }

        return lines.joined(
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
                width
            )
        )
        .ansi(
            .brightBlack
        )
    }

    private static func guidelineCountDescription(
        _ count: Int
    ) -> String {
        count == 1
            ? "1 guideline"
            : "\(count) guidelines"
    }

    private static func wrap(
        _ content: String,
        width: Int
    ) -> String {
        TerminalTextWrap
            .lines(
                normalizedProse(
                    content
                ),
                width: width
            )
            .joined(
                separator: "\n"
            )
    }

    private static func styledLines(
        _ content: String,
        style: TerminalStyle
    ) -> String {
        let lines = content
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)

        return style
            .apply(
                lines: lines
            )
            .joined(
                separator: "\n"
            )
    }

    private static func normalizedProse(
        _ content: String
    ) -> String {
        content
            .split(
                whereSeparator:
                    \.isWhitespace
            )
            .joined(
                separator: " "
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
}
