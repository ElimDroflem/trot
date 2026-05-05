import SwiftUI
import SwiftData

struct WalkWindowsCard: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        FormCard(title: "Walk windows") {
            ForEach(Array(WalkSlot.allCases.enumerated()), id: \.offset) { index, slot in
                if index > 0 { FormDivider() }
                FormRow(label: label(for: slot)) {
                    Toggle("", isOn: bindingFor(slot: slot))
                        .labelsHidden()
                        .tint(.brandPrimary)
                }
            }
        }
    }

    // MARK: - Binding

    private func bindingFor(slot: WalkSlot) -> Binding<Bool> {
        Binding(
            get: { isEnabled(slot: slot) },
            set: { newValue in setEnabled(slot: slot, enabled: newValue) }
        )
    }

    private func isEnabled(slot: WalkSlot) -> Bool {
        guard let window = window(for: slot) else { return false }
        return window.enabled
    }

    private func setEnabled(slot: WalkSlot, enabled: Bool) {
        if enabled {
            if let existing = window(for: slot) {
                existing.enabled = true
            } else {
                let window = WalkWindow(slot: slot, enabled: true, dog: dog)
                modelContext.insert(window)
                if dog.walkWindows == nil {
                    dog.walkWindows = [window]
                } else {
                    dog.walkWindows?.append(window)
                }
            }
        } else {
            if let existing = window(for: slot) {
                modelContext.delete(existing)
            }
        }
        try? modelContext.save()
    }

    private func window(for slot: WalkSlot) -> WalkWindow? {
        (dog.walkWindows ?? []).first(where: { $0.slot == slot })
    }

    // MARK: - Display

    private func label(for slot: WalkSlot) -> String {
        switch slot {
        case .earlyMorning: return "Early morning (5–9)"
        case .lunch: return "Lunchtime (11–2)"
        case .afternoon: return "Afternoon (2–6)"
        case .evening: return "Evening (6–10)"
        }
    }
}
