import SwiftUI

struct PreferenceEditorView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss

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
                            selected: store.profile.roles,
                            toggle: store.toggleRole
                        )

                        editorSection(
                            "you're into",
                            values: DunnoTaxonomy.interests.map(\.title),
                            selected: store.profile.interests,
                            toggle: store.toggleInterest
                        )

                        editorSection(
                            "what dunno should find",
                            values: DunnoTaxonomy.goals.map(\.title),
                            selected: store.profile.goals,
                            toggle: store.toggleGoal
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .font(Font.dunno(15, weight: .semibold))
                }
            }
        }
    }

    private func editorSection(
        _ title: String,
        values: [String],
        selected: [String],
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
}
