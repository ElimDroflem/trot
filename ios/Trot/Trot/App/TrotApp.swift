import SwiftUI
import SwiftData

@main
struct TrotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: TrotSchemaV1.self)

        // ← THE ONE LINE. End of build: change `.none` to
        //   .private("iCloud.dog.trot.Trot")
        // and deploy CloudKit schema (Development → Production).
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: TrotMigrationPlan.self,
                configurations: [configuration]
            )
            // Promote any legacy UserDefaults chapter-seen flags onto the
            // SwiftData `seenAt` field so existing installs don't re-fire
            // the chapter-close overlay after this build lands.
            // Cheap + idempotent; runs in DEBUG and Release.
            StoryService.migrateLegacyChapterSeenState(in: container.mainContext)
            #if DEBUG
            DebugSeed.seedIfEmpty(container: container)
            #endif
            return container
        } catch {
            fatalError("ModelContainer construction failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        #if DEBUG
        DebugDeepLinks.handle(
            url,
            appState: appState,
            modelContext: modelContainer.mainContext
        )
        #endif
    }
}
