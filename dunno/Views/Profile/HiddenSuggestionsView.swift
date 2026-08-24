import SwiftUI

struct HiddenSuggestionsView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRestoreAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("see less like this")
                                .font(Font.dunnoRounded(29, weight: .bold))

                            Text("These are ideas you explicitly told Dunno to move away from. Restore one anytime if you change your mind.")
                                .font(Font.dunno(14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }

                        if store.hiddenActivities.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "eye")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.dunnoPurple)

                                Text("nothing hidden")
                                    .font(Font.dunnoRounded(19, weight: .bold))

                                Text("If you use “Show me less like this,” you can undo that choice here later.")
                                    .font(Font.dunno(13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 290)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 70)
                        } else {
                            LazyVStack(spacing: 9) {
                                ForEach(store.hiddenActivities) { activity in
                                    HStack(spacing: 10) {
                                        ActivityRowView(activity: activity, trailingSystemImage: nil)
                                            .allowsHitTesting(false)

                                        Button("restore") {
                                            store.restoreSuggestion(activity)
                                        }
                                        .font(Font.dunno(12.5, weight: .bold))
                                        .foregroundStyle(Color.dunnoPurple)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("hidden suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.hiddenActivities.count > 1 {
                        Button("restore all") {
                            confirmRestoreAll = true
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .font(Font.dunno(15, weight: .semibold))
                }
            }
        }
        .alert("Restore every hidden suggestion?", isPresented: $confirmRestoreAll) {
            Button("Cancel", role: .cancel) { }
            Button("restore all") {
                store.restoreAllHiddenSuggestions()
            }
        } message: {
            Text("Dunno will be allowed to suggest these ideas again.")
        }
    }
}
