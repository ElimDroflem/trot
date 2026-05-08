import SwiftUI
import SwiftData

/// The 5-item vertical ladder showing where the user is in the current
/// chapter. Per Corey's spec: exactly five items, no more, no less. Two
/// past pages, one current (pulsing), two upcoming. The upcoming pages
/// fade by opacity (full → 50% → 25%) so the future feels anticipatory
/// rather than gated.
///
/// For chapters with fewer than three past pages (e.g. user is on page 1
/// or 2), we collapse the future to fill the missing items — the ladder
/// always renders five rows so the visual rhythm doesn't shift as the
/// chapter progresses.
struct ChapterSpine: View {
    let chapter: StoryChapter?
    /// The page the user is currently looking at — the row that pulses.
    let currentPage: StoryPage
    let genre: StoryGenre

    private let dotSize: CGFloat = 14

    var body: some View {
        let rows = buildRows()
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                spineRow(row, isFirst: index == 0, isLast: index == rows.count - 1)
            }
        }
        .padding(Space.md)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    // MARK: - Row

    @ViewBuilder
    private func spineRow(_ row: SpineRow, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(connectorColor(for: row))
                    .frame(width: 2, height: 12)
                    .opacity(isFirst ? 0 : 1)
                ZStack {
                    Circle()
                        .fill(dotFill(for: row))
                        .frame(width: dotSize, height: dotSize)
                    if row.kind == .current {
                        Circle()
                            .stroke(genre.accentColor, lineWidth: 2)
                            .frame(width: dotSize + 8, height: dotSize + 8)
                    }
                }
                Rectangle()
                    .fill(connectorColor(for: row))
                    .frame(width: 2, height: 24)
                    .opacity(isLast ? 0 : 1)
            }
            .frame(width: dotSize + 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(labelColor(for: row))
                if let snippet = row.snippet {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(snippetColor(for: row))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
            .opacity(opacity(for: row))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Building rows

    private func buildRows() -> [SpineRow] {
        let pages = chapter?.orderedPages ?? []
        let currentIndex = pages.firstIndex { $0.persistentModelID == currentPage.persistentModelID } ?? (pages.count - 1)
        var rows: [SpineRow] = []

        // Build five rows. We want: 2 past + current + 2 upcoming.
        // If fewer past pages exist, the upcoming fills more rows.
        // If we're at the chapter end (page 5), all 5 are past or current.
        for offset in -2...2 {
            let pageIndex = currentIndex + offset
            if pageIndex < 0 {
                // Earlier than the chapter began — show "Story so far"
                // for the very first chapter, or a recap line for later.
                rows.append(SpineRow(
                    kind: .preChapter,
                    label: chapter?.index ?? 1 > 1 ? "Previously" : "Day one",
                    snippet: nil
                ))
            } else if pageIndex < pages.count {
                let page = pages[pageIndex]
                let isCurrent = offset == 0
                rows.append(SpineRow(
                    kind: isCurrent ? .current : .past,
                    label: "Page \(page.index)",
                    snippet: shortenSnippet(page.prose)
                ))
            } else if pageIndex == pages.count {
                // The next page — described by the path teasers from
                // the current page.
                rows.append(SpineRow(
                    kind: .nextLocked,
                    label: "Page \(pageIndex + 1)",
                    snippet: pathTeaser(for: currentPage)
                ))
            } else {
                rows.append(SpineRow(
                    kind: .farLocked,
                    label: "Page \(pageIndex + 1)",
                    snippet: nil
                ))
            }
        }

        return rows
    }

    private func shortenSnippet(_ prose: String) -> String? {
        let trimmed = prose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // First sentence or 80 chars, whichever comes first.
        let firstSentenceEnd = trimmed.firstIndex { ".!?".contains($0) }
        if let end = firstSentenceEnd, trimmed.distance(from: trimmed.startIndex, to: end) <= 80 {
            return String(trimmed[..<trimmed.index(after: end)])
        }
        if trimmed.count <= 80 { return trimmed }
        let cut = trimmed.index(trimmed.startIndex, offsetBy: 80)
        return String(trimmed[..<cut]) + "…"
    }

    private func pathTeaser(for page: StoryPage) -> String? {
        // For the locked next-page row, show one of the path teasers as
        // the snippet — gives the future texture.
        let a = page.pathChoiceA.trimmingCharacters(in: .whitespacesAndNewlines)
        if !a.isEmpty { return a }
        let b = page.pathChoiceB.trimmingCharacters(in: .whitespacesAndNewlines)
        return b.isEmpty ? nil : b
    }

    // MARK: - Visual mappings

    private func dotFill(for row: SpineRow) -> Color {
        switch row.kind {
        case .past, .preChapter: return genre.accentColor
        case .current:           return genre.accentColor
        case .nextLocked:        return genre.accentColor.opacity(0.50)
        case .farLocked:         return Color.brandDivider
        }
    }

    private func connectorColor(for row: SpineRow) -> Color {
        switch row.kind {
        case .past, .preChapter, .current: return genre.accentColor.opacity(0.55)
        case .nextLocked:                   return genre.accentColor.opacity(0.25)
        case .farLocked:                    return Color.brandDivider
        }
    }

    private func labelColor(for row: SpineRow) -> Color {
        switch row.kind {
        case .past, .preChapter: return Color.brandTextSecondary
        case .current:           return Color.brandTextPrimary
        case .nextLocked:        return Color.brandTextSecondary
        case .farLocked:         return Color.brandTextTertiary
        }
    }

    private func snippetColor(for row: SpineRow) -> Color {
        switch row.kind {
        case .past, .preChapter, .current: return Color.brandTextSecondary
        case .nextLocked:                   return Color.brandTextSecondary
        case .farLocked:                    return Color.brandTextTertiary
        }
    }

    private func opacity(for row: SpineRow) -> Double {
        switch row.kind {
        case .past, .preChapter: return 1.0
        case .current:           return 1.0
        case .nextLocked:        return 0.65
        case .farLocked:         return 0.35
        }
    }
}

// MARK: - Row model

private struct SpineRow {
    enum Kind {
        case preChapter   // before chapter 1 page 1 (placeholder)
        case past         // a page already written in the current chapter
        case current      // the page the user is reading right now
        case nextLocked   // immediate next page (full opacity, named teaser)
        case farLocked    // two pages ahead (silhouette)
    }
    let kind: Kind
    let label: String
    let snippet: String?
}
