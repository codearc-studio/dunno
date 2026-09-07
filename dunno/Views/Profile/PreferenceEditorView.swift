import SwiftUI
import UIKit

struct PreferenceEditorView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss

    @State private var draftRoles: Set<String> = []
    @State private var draftInterests: Set<String> = []
    @State private var draftGoals: Set<String> = []
    @State private var loadedDraft = false

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("fine-tune dunno")
                                .font(Font.dunnoRounded(29, weight: .bold))
                                .tracking(-0.35)

                            Text("Broad hints only. Right now stays temporary, and normal swipes don't rewrite your profile.")
                                .font(Font.dunno(14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }

                        editorSection(
                            "sounds like you",
                            values: DunnoTaxonomy.roles.map(\.title),
                            selected: draftRoles,
                            toggle: { toggle($0, in: $draftRoles) }
                        )

                        editorSection(
                            "you're into",
                            values: DunnoTaxonomy.interests.map(\.title),
                            selected: draftInterests,
                            toggle: { toggle($0, in: $draftInterests) }
                        )

                        editorSection(
                            "what dunno should find",
                            values: DunnoTaxonomy.goals.map(\.title),
                            selected: draftGoals,
                            toggle: { toggle($0, in: $draftGoals) }
                        )
                    }
                    .frame(maxWidth: 780, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") {
                        commitDraft()
                        dismiss()
                    }
                    .font(Font.dunno(15, weight: .semibold))
                }
            }
        }
        .onAppear(perform: loadDraftIfNeeded)
        .onDisappear(perform: commitDraft)
    }

    private func editorSection(
        _ title: String,
        values: [String],
        selected: Set<String>,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            DunnoSectionHeader(title: title)

            FlowLayout(spacing: 7) {
                ForEach(values, id: \.self) { value in
                    DunnoPill(
                        title: value,
                        systemImage: nil,
                        isSelected: selected.contains(value)
                    ) {
                        toggle(value)
                    }
                }
            }
        }
    }

    private func loadDraftIfNeeded() {
        guard !loadedDraft else { return }
        draftRoles = Set(store.profile.roles)
        draftInterests = Set(store.profile.interests)
        draftGoals = Set(store.profile.goals)
        loadedDraft = true
    }

    private func commitDraft() {
        guard loadedDraft else { return }

        store.updatePreferences(
            roles: DunnoTaxonomy.roles.map(\.title).filter(draftRoles.contains),
            interests: DunnoTaxonomy.interests.map(\.title).filter(draftInterests.contains),
            goals: DunnoTaxonomy.goals.map(\.title).filter(draftGoals.contains)
        )
    }

    private func toggle(_ value: String, in selection: Binding<Set<String>>) {
        var updated = selection.wrappedValue
        if updated.contains(value) {
            updated.remove(value)
        } else {
            updated.insert(value)
        }
        selection.wrappedValue = updated
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
