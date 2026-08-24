import Terminal

enum GuidelineDocumentViewerAction:
    Sendable,
    Hashable
{
    case previous
    case next
    case back
}

struct GuidelineDocumentViewerResult:
    Sendable,
    Hashable
{
    let action: GuidelineDocumentViewerAction
    let offset: Int
}

struct GuidelineDocumentViewer {
    private struct Geometry {
        let rows: Int
        let columns: Int
        let contentRows: Int
        let maximumOffset: Int
    }

    private let outputStream: TerminalStream

    init(
        outputStream: TerminalStream = .standardError
    ) {
        self.outputStream = outputStream
    }

    func run(
        document: String,
        initialOffset: Int = 0,
        hasPrevious: Bool,
        hasNext: Bool
    ) throws -> GuidelineDocumentViewerResult {
        let session = try TerminalSession(
            options:
                TerminalSession.Options(
                    useAlternateScreen: false,
                    hideCursor: true,
                    useRawMode: true,
                    restoreOnInterrupt: true,
                    outputStream: outputStream
                )
        )

        defer {
            session.restore()
        }

        let reader = TerminalKeyReader()

        let lines = document
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(
                String.init
            )

        var geometry = resolveGeometry(
            lineCount: lines.count
        )

        var offset = clampedOffset(
            initialOffset,
            maximum: geometry.maximumOffset
        )

        while true {
            geometry = resolveGeometry(
                lineCount: lines.count
            )

            offset = clampedOffset(
                offset,
                maximum: geometry.maximumOffset
            )

            render(
                lines: lines,
                offset: offset,
                geometry: geometry,
                hasPrevious: hasPrevious,
                hasNext: hasNext
            )

            let key = reader.readKey()

            switch key {
            case .down,
                 .char("j"),
                 .control("N"):
                offset = clampedOffset(
                    offset + 1,
                    maximum: geometry.maximumOffset
                )

            case .up,
                 .char("k"),
                 .control("P"):
                offset = clampedOffset(
                    offset - 1,
                    maximum: geometry.maximumOffset
                )

            case .pageDown,
                 .space:
                offset = clampedOffset(
                    offset
                    + pageDistance(
                        geometry
                    ),
                    maximum: geometry.maximumOffset
                )

            case .pageUp:
                offset = clampedOffset(
                    offset
                    - pageDistance(
                        geometry
                    ),
                    maximum: geometry.maximumOffset
                )

            case .control("D"):
                offset = clampedOffset(
                    offset
                    + halfPageDistance(
                        geometry
                    ),
                    maximum: geometry.maximumOffset
                )

            case .control("U"):
                offset = clampedOffset(
                    offset
                    - halfPageDistance(
                        geometry
                    ),
                    maximum: geometry.maximumOffset
                )

            case .home,
                 .char("g"):
                offset = 0

            case .end,
                 .char("G"):
                offset =
                    geometry.maximumOffset

            case .left:
                guard hasPrevious else {
                    continue
                }

                return GuidelineDocumentViewerResult(
                    action: .previous,
                    offset: offset
                )

            case .right:
                guard hasNext else {
                    continue
                }

                return GuidelineDocumentViewerResult(
                    action: .next,
                    offset: offset
                )

            case .char("q"),
                 .escape:
                return GuidelineDocumentViewerResult(
                    action: .back,
                    offset: offset
                )

            default:
                break
            }
        }
    }

    private func resolveGeometry(
        lineCount: Int
    ) -> Geometry {
        let size = Terminal.size(
            for: outputStream
        )

        let contentRows = max(
            1,
            size.rows - 3
        )

        return Geometry(
            rows: size.rows,
            columns: size.columns,
            contentRows: contentRows,
            maximumOffset:
                max(
                    0,
                    lineCount - contentRows
                )
        )
    }

    private func render(
        lines: [String],
        offset: Int,
        geometry: Geometry,
        hasPrevious: Bool,
        hasNext: Bool
    ) {
        let end = min(
            lines.count,
            offset + geometry.contentRows
        )

        var frame: [String]

        if offset < end {
            frame = Array(
                lines[offset..<end]
            )
        } else {
            frame = []
        }

        while frame.count
            < geometry.contentRows
        {
            frame.append("")
        }

        frame.append(
            String(
                repeating: "─",
                count: max(
                    1,
                    geometry.columns
                )
            )
            .ansi(
                .brightBlack
            )
        )

        let visibleStart =
            lines.isEmpty
            ? 0
            : min(
                lines.count,
                offset + 1
            )

        let visibleEnd =
            lines.isEmpty
            ? 0
            : end

        frame.append(
            fitted(
                "\(visibleStart)–\(visibleEnd) / \(lines.count)",
                columns: geometry.columns
            )
            .ansi(
                .brightBlack
            )
        )

        frame.append(
            fitted(
                instructions(
                    hasPrevious: hasPrevious,
                    hasNext: hasNext
                ),
                columns: geometry.columns
            )
            .ansi(
                .brightBlack
            )
        )

        Terminal.clearScreen(
            to: outputStream
        )

        Terminal.moveCursor(
            line: 1,
            column: 1,
            to: outputStream
        )

        Terminal.write(
            frame.joined(
                separator: "\n"
            ),
            to: outputStream
        )

        Terminal.flush(
            outputStream
        )
    }

    private func instructions(
        hasPrevious: Bool,
        hasNext: Bool
    ) -> String {
        var components = [
            "j/k scroll",
            "PgUp/PgDn page",
            "g/G ends",
        ]

        if hasPrevious || hasNext {
            components.append(
                "←/→ prev/next"
            )
        }

        components.append(
            "q back"
        )

        return components.joined(
            separator: "  "
        )
    }

    private func fitted(
        _ text: String,
        columns: Int
    ) -> String {
        String(
            text.prefix(
                max(
                    1,
                    columns
                )
            )
        )
    }

    private func clampedOffset(
        _ value: Int,
        maximum: Int
    ) -> Int {
        min(
            max(
                0,
                value
            ),
            maximum
        )
    }

    private func pageDistance(
        _ geometry: Geometry
    ) -> Int {
        max(
            1,
            geometry.contentRows - 1
        )
    }

    private func halfPageDistance(
        _ geometry: Geometry
    ) -> Int {
        max(
            1,
            geometry.contentRows / 2
        )
    }
}
