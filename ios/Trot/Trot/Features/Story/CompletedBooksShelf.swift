import SwiftUI
import SwiftData

/// Horizontal shelf of finished books, shown beneath the genre picker
/// once the user has completed at least one book. Each card carries the
/// genre's chrome (book surface, border, accent dot) plus the title and
/// a "n pages · finished MMM yyyy" footer. Tap → opens the book in the
/// existing `StoryFullPageReader`, scoped to that book's pages.
///
/// The active book never appears here — only stories with `finishedAt`
/// set. Sort is newest-first via `Dog.completedStoriesSorted`.
struct CompletedBooksShelf: View {
    let stories: [Story]
    var onTap: (Story) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandSecondary)
                Text("Previous books")
                    .font(.titleSmall.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
            }
            .padding(.horizontal, Space.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.md) {
                    ForEach(stories, id: \.persistentModelID) { story in
                        Button { onTap(story) } label: {
                            bookCard(for: story)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.md)
            }
        }
    }

    private func bookCard(for story: Story) -> some View {
        let genre = story.genre
        let pageCount = (story.chapters ?? []).flatMap { $0.pages ?? [] }.count
        let dateString: String = {
            guard let finishedAt = story.finishedAt else { return "Recent" }
            let f = DateFormatter()
            f.dateFormat = "MMM yyyy"
            return f.string(from: finishedAt)
        }()
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: genre.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(genre.accentColor)
                Text(genre.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(genre.bookMetaColor)
            }

            Text(story.title.isEmpty ? "Untitled" : story.title)
                .font(.titleSmall.weight(.semibold))
                .foregroundStyle(genre.bookProseColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("\(pageCount) pages · \(dateString)")
                .font(.caption2)
                .foregroundStyle(genre.bookMetaColor)
        }
        .padding(Space.md)
        .frame(width: 200, height: 140, alignment: .topLeading)
        .background(genre.bookSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(genre.bookBorder, lineWidth: 1)
        )
        .brandCardShadow()
    }
}

