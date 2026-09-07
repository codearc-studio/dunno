import SwiftUI

struct DunnoActivityNoteEditor: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let activity: DunnoActivity
    @State private var note: String

    init(activity: DunnoActivity, existingNote: String = "") {
        self.activity = activity
        _note = State(initialValue: existingNote)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("remember anything?")
                            .font(Font.dunnoRounded(24, weight: .bold))
                        Text(activity.title)
                            .font(Font.dunno(13.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $note)
                        .font(Font.dunno(16, weight: .medium))
                        .scrollContentBackground(.hidden)
                        .padding(13)
                        .frame(minHeight: 180, maxHeight: 320)
                        .dunnoGlassPanel(cornerRadius: 20, interactive: true)
                        .focused($isFocused)
                        .accessibilityLabel("Private activity note")

                    Text("private · saved only on this device")
                        .font(Font.dunno(11.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        store.setNote(note, for: activity)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if note.isEmpty { note = store.note(for: activity) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isFocused = true }
        }
    }
}
