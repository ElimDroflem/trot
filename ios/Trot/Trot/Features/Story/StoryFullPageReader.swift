import SwiftUI
import SwiftData

/// Distraction-free full-screen presentation of one page at a time, with
/// horizontal swipe navigation across the whole story (cross-chapter).
/// Triggered from the "Read more" pill on `StoryPageReader` and from
/// taps on rows in `ChapterSpine`.
///
/// Why cross-chapter swipe: from the user's point of view the book is
/// one continuous thing, not a chaptered structure. Swiping from
/// chapter 2 page 1 back to chapter 1 page 5 should "just work."
/// Closed chapters get their own deeper rereading mode in
/// `StoryChapterReader` (vertical scroll of every page in that
/// chapter); this view is for one-page-at-a-time browsing.
///
/// Layout:
///   - Same `GenreAtmosphereLayer` + `GenreOverlay` as the live tab so
///     the world doesn't change when the user dives in.
///   - Each "page" inside the TabView is a single page card (header +
///     prose + optional photo) that fits the iPhone screen at body
///     font, in line with the new ~160-word page target.
///   - Swipe indicator dots at the bottom (default `.page` style).
///   - Close button top-right.
struct StoryFullPageReader: View {
    let genre: StoryGenre
    let pages: [StoryPage]
    let onClose: () -> Void

    /// Index into `pages` of the page currently shown. Bound to the
    /// underlying `TabView` selection so swiping updates it. Starting
    /// value comes from the caller — usually the latest page or the
    /// page tapped in the spine.
    @State private var currentIndex: Int

    init(
        genre: StoryGenre,
        pages: [StoryPage],
        startIndex: Int,
        onClose: @escaping () -> Void
    ) {
        self.genre = genre
        self.pages = pages
        self.onClose = onClose
        // Clamp into range so a stale startIndex (e.g. last page got
        // deleted between open + render) doesn't crash the TabView.
        let clamped = max(0, min(startIndex, max(0, pages.count - 1)))
        self._currentIndex = State(initialValue: clamped)
    }

    var body: some View {
        ZStack {
            // Same layered backdrop as the Story tab, so opening the
            // full reader feels like sliding deeper into the same
            // world rather than crossing into a sheet.
            LinearGradient(
                colors: [Color.brandSurface, Color.brandSurfaceSunken],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GenreAtmosphereLayer(genre: genre)
            GenreOverlay(genre: genre)

            if pages.isEmpty {
                // Defensive — caller shouldn't open the reader with no
                // pages, but if they do we render a calm empty state
                // rather than a crashed TabView.
                emptyState
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.persistentModelID) { index, page in
                        pageView(for: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            }
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .overlay(alignment: .top) { topMeta }
    }

    // MARK: - Page

    @ViewBuilder
    private func pageView(for page: StoryPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                GenrePageHeader(
                    genre: genre,
                    pageGlobalIndex: page.globalIndex,
                    chapterIndex: page.chapter?.index ?? 1,
                    pageInChapter: page.index
                )

                if let data = page.photo, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(genre.bookBorder, lineWidth: 1)
                        )
                }

                GenreProseView(genre: genre, prose: page.prose)

                // Bottom padding accommodates the page indicator dots
                // and gives breathing room at the foot of the page.
                Color.clear.frame(height: Space.xxl)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .genreBookCard(genre)
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xxl)
            .padding(.bottom, Space.lg)
        }
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(genre.bookProseColor.opacity(0.85))
                .background(
                    Circle()
                        .fill(genre.bookSurface)
                        .padding(2)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, Space.md)
        .padding(.trailing, Space.md)
    }

    /// Top-of-screen "page X of Y" hint so the user knows where they
    /// are in the swipe stack. Sits just under the Dynamic Island and
    /// reads as a thin spine number, not chrome.
    private var topMeta: some View {
        Group {
            if !pages.isEmpty {
                Text("\(currentIndex + 1) / \(pages.count)")
                    .font(.system(.caption2, design: genre.bodyFontDesign).weight(.bold))
                    .tracking(2.0)
                    .foregroundStyle(genre.accentColor.opacity(0.75))
                    .padding(.top, Space.sm)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(genre.bookMetaColor)
            Text("Nothing to read yet.")
                .font(.titleMedium)
                .foregroundStyle(genre.bookProseColor)
        }
        .padding(Space.xl)
    }
}
