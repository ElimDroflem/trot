import SwiftUI
import SwiftData

struct DayWalksSheet: View {
    let date: Date
    let dog: Dog

    @Environment(\.dismiss) private var dismiss
    @State private var showingLogWalk = false
    @State private var editingWalk: Walk?

    private var walksOnDay: [Walk] {
        let calendar = Calendar.current
        return (dog.walks ?? [])
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var isFutureDay: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.lg) {
                        header
                        if walksOnDay.isEmpty {
                            emptyState
                        } else {
                            walksList
                        }
                        if !isFutureDay {
                            logWalkButton
                        }
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            }
            .navigationTitle(dayHeading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
            .sheet(isPresented: $showingLogWalk) {
                LogWalkSheet(dogs: [dog], initialDate: date)
            }
            .sheet(item: $editingWalk) { walk in
                LogWalkSheet(dogs: [dog], editingWalk: walk)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        let total = walksOnDay.reduce(0) { $0 + $1.durationMinutes }
        return VStack(spacing: Space.xs) {
            Text(walksOnDay.isEmpty ? "No walks logged" : "\(total) minutes total")
                .font(.titleLarge)
                .foregroundStyle(Color.brandSecondary)
        }
        .padding(.top, Space.sm)
    }

    private var emptyState: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "pawprint")
                .font(.system(size: 32))
                .foregroundStyle(Color.brandTextTertiary)
            Text(isFutureDay ? "This day hasn't happened yet." : "Nothing logged for this day.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    private var walksList: some View {
        VStack(spacing: Space.sm) {
            ForEach(walksOnDay) { walk in
                Button(action: { editingWalk = walk }) {
                    walkRow(walk)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Tap to edit or delete this walk.")
            }
        }
    }

    private func walkRow(_ walk: Walk) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 40, height: 40)
                .background(Color.brandPrimaryTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(walk.durationMinutes)-minute walk")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(timeText(for: walk))
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandTextTertiary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private var logWalkButton: some View {
        Button(action: { showingLogWalk = true }) {
            HStack(spacing: Space.xs) {
                Image(systemName: "plus")
                Text("Log a walk")
            }
            .font(.bodyLarge.weight(.semibold))
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.brandPrimary, lineWidth: 1.5)
            }
        }
        .padding(.top, Space.sm)
    }

    // MARK: - Helpers

    private var dayHeading: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    private func timeText(for walk: Walk) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "h:mm a"
        let timeText = formatter.string(from: walk.startedAt).lowercased()
        let sourceText = walk.source == .passive ? "Passive" : "Manual"
        return "\(timeText) · \(sourceText)"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Dog.self, Walk.self, WalkWindow.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let dog = Dog(
        name: "Luna",
        breedPrimary: "Beagle",
        dateOfBirth: Date(timeIntervalSince1970: 0),
        weightKg: 12,
        sex: .female,
        isNeutered: true
    )
    return DayWalksSheet(date: .now, dog: dog)
        .modelContainer(container)
}
