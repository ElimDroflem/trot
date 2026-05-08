import SwiftUI
import SwiftData

/// Full-screen presentation of a completed chapter — every page in
/// reading order, with photos inline if the user attached any. Themed
/// by the chapter's genre.
struct StoryChapterReader: View {
    let chapter: StoryChapter
    let genre: StoryGenre

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: genre.primaryColor.opacity(0.92), location: 0.0),
                    .init(color: genre.midColor.opacity(0.50), location: 0.18),
                    .init(color: Color.brandSurface, location: 0.45),
                    .init(color: Color.brandSurfaceSunken, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Same medium overlay as the live story page — film grain,
            // scanlines, etc. — so the chapter-reader sheet feels like
            // turning back the same physical book.
            GenreOverlay(genre: genre)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header

                    ForEach(chapter.orderedPages, id: \.persistentModelID) { page in
                        pageBlock(page)
                    }

                    closing

                    Color.clear.frame(height: Space.xl)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.lg)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .background(Color.black.opacity(0.4).clipShape(Circle()))
                    .padding(Space.md)
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: genre.symbol)
                    .font(.caption.weight(.semibold))
                Text("CHAPTER \(chapter.index)")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
            }
            .foregroundStyle(.white.opacity(0.85))
            Text(chapter.title)
                .font(.displayLarge)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
    }

    private func pageBlock(_ page: StoryPage) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            GenrePageHeader(
                genre: genre,
                pageGlobalIndex: page.globalIndex,
                chapterIndex: chapter.index,
                pageInChapter: page.index
            )
            GenreProseView(genre: genre, prose: page.prose)
            if let data = page.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(genre.bookBorder, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .genreBookCard(genre)
    }

    private var closing: some View {
        Text(chapter.closingLine)
            .font(.system(.title3, design: genre.bodyFontDesign))
            .italic()
            .foregroundStyle(genre.primaryColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Space.lg)
            .frame(maxWidth: .infinity)
    }
}
