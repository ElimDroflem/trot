import Foundation
import SwiftData

/// Per-dog narrative shell. Holds the chosen genre + a rolling "story
/// bible" string that the LLM keeps regenerating at chapter close so plot,
/// characters, and loose ends survive across the page generations.
///
/// Why bible-as-string instead of a structured field: the LLM needs to
/// READ it on every page generation as part of the system prompt, so
/// keeping it as freeform prose is cheaper (one tokenisation, no
/// reassembly) and the model picks the structure naturally.
///
/// CloudKit-friendly: every field has a default. Relationships are
/// optional. Photos use `@Attribute(.externalStorage)`.
@Model
final class Story {
    /// Genre raw value (`StoryGenre.rawValue`). Stored as String for
    /// CloudKit primitive compatibility; `genre` computed property maps to
    /// the typed enum.
    var genreRaw: String = ""

    /// Scene raw id picked by the user on the scene-setter step that
    /// follows genre commit. Empty string for legacy stories that
    /// existed before the scene picker shipped — the LLM falls through
    /// to the generic prologue path. Stored as primitive String for
    /// CloudKit; `scene` computed property maps to the typed value.
    var sceneRaw: String = ""

    /// Rolling LLM-generated state. Updated at chapter close: characters
    /// introduced, current setting, open threads. Sent on every page
    /// prompt so continuity survives.
    var bible: String = ""

    var startedAt: Date = Date()

    /// Set the moment a book ends (final chapter closed). nil = active
    /// book; non-nil = archived. The Dog moves the Story from its
    /// `story` (active) relationship into `completedStories` at finish
    /// time, but the timestamp lives on the Story itself so any view
    /// can sort/filter without joining back to Dog.
    var finishedAt: Date?

    /// LLM-generated book title, set when the book ends. Suitable for a
    /// printed spine: 3-7 words, atmospheric, no subtitle. Empty until
    /// finish.
    var title: String = ""

    /// LLM-generated last line of the BOOK (distinct from a chapter
    /// closing line). 12-22 words. Empty until finish.
    var closingLine: String = ""

    /// All chapters in this story, in `index` order. Length-of-array =
    /// number of chapters started; the most-recent chapter is the active
    /// one if its `closedAt` is nil.
    @Relationship(deleteRule: .cascade, inverse: \StoryChapter.story)
    var chapters: [StoryChapter]? = []

    init(genre: StoryGenre) {
        self.genreRaw = genre.rawValue
    }

    /// Typed accessor — falls back to `.adventure` if the raw value somehow
    /// drifts (CloudKit roundtrip, app version mismatch).
    var genre: StoryGenre {
        get { StoryGenre(rawValue: genreRaw) ?? .adventure }
        set { genreRaw = newValue.rawValue }
    }

    /// Typed accessor for the picked scene, or nil if `sceneRaw` is empty
    /// (legacy story) or the id no longer matches a known scene under the
    /// current genre (e.g. data drift after a v1.x scene-table change).
    var scene: StoryGenre.Scene? {
        guard !sceneRaw.isEmpty else { return nil }
        return genre.scene(forID: sceneRaw)
    }

    /// The currently-open chapter (no closedAt). Nil if every chapter has
    /// closed and the next one hasn't started yet.
    var currentChapter: StoryChapter? {
        let sorted = (chapters ?? []).sorted { $0.index < $1.index }
        return sorted.last(where: { $0.closedAt == nil })
    }

    /// Highest chapter index across the story, used to assign the next
    /// chapter's `index`.
    var maxChapterIndex: Int {
        (chapters ?? []).map(\.index).max() ?? 0
    }
}

/// A chapter is exactly 5 pages. Title and closing line are LLM-generated
/// when the chapter wraps. `closedAt` is nil while the chapter is in
/// progress and stamped with a Date the moment the 5th page lands.
@Model
final class StoryChapter {
    /// 1-indexed across the story. First chapter is index = 1.
    var index: Int = 0

    /// LLM-generated chapter title. Empty until the chapter closes.
    var title: String = ""

    /// LLM-generated one-line closing flourish ("...and the cheese was
    /// gone"). Empty until close.
    var closingLine: String = ""

    /// Set when the 5th page lands and the close-LLM-call returns. Nil
    /// while the chapter is the active one.
    var closedAt: Date?

    /// Set the moment the user dismisses the chapter-close celebration.
    /// `nil` while a closed chapter has yet to be seen, non-nil once it
    /// has. Replaces the install-scoped UserDefaults flag the close
    /// overlay used to key on, which broke on every reinstall because
    /// `persistentModelID.hashValue` changes per install. SwiftData-
    /// backed means this survives reinstall and CloudKit sync.
    var seenAt: Date?

    var startedAt: Date = Date()

    var story: Story?

    @Relationship(deleteRule: .cascade, inverse: \StoryPage.chapter)
    var pages: [StoryPage]? = []

    init(index: Int) {
        self.index = index
    }

    /// Pages in `index` order.
    var orderedPages: [StoryPage] {
        (pages ?? []).sorted { $0.index < $1.index }
    }

    /// True when the user has hit the 5-page count. Used by StoryService
    /// to decide whether to fire `closeChapter`.
    var isFull: Bool { (pages?.count ?? 0) >= 5 }

    /// 0...1 progress for the on-screen ring around the dog photo.
    var progressFraction: Double {
        let count = pages?.count ?? 0
        return min(1.0, Double(count) / 5.0)
    }
}

/// One page of prose, plus the two AI-generated path teasers for the next
/// page. The user's choice of path (or their text/photo) gets recorded on
/// the page that consumed it — so a user who picks "investigate the shed"
/// has that recorded on the page they made the choice from, and the next
/// page's prose follows from it.
@Model
final class StoryPage {
    /// 1-indexed within the chapter (1...5).
    var index: Int = 0

    /// 1-indexed across the entire story. Page 1 chapter 2 has globalIndex 6.
    var globalIndex: Int = 0

    /// 40-60 word page body. The actual narrative.
    var prose: String = ""

    /// Two LLM-generated path teasers for what could happen next. Shown
    /// as buttons on the current page so the user can pick a direction
    /// for the next page without writing anything.
    var pathChoiceA: String = ""
    var pathChoiceB: String = ""

    /// Where the user took the story from this page. Possible values:
    ///   - "a" / "b" — picked one of the two AI teasers
    ///   - "text" — wrote their own
    ///   - "photo" — uploaded an image (with optional text alongside)
    ///   - "" — no choice yet (this page is the latest, awaiting user input)
    var userChoice: String = ""

    /// Optional free-text the user wrote when picking a direction.
    /// Combines with `userChoice` (a, b, photo) to inform the next page.
    var userText: String = ""

    /// Optional photo the user uploaded with their choice. `nil` for pages
    /// where the user didn't add a photo. Photos persist forever — the book
    /// becomes a memory book over time.
    @Attribute(.externalStorage) var photo: Data?

    var createdAt: Date = Date()

    var chapter: StoryChapter?

    init(index: Int, globalIndex: Int) {
        self.index = index
        self.globalIndex = globalIndex
    }

    /// True when the user has committed to a direction from this page —
    /// once true, the next page is being / can be generated. Pages with
    /// no commitment yet are the "current" page (they're the most recent
    /// and still inviting input).
    var hasUserChoice: Bool { !userChoice.isEmpty }
}
