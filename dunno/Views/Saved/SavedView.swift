import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var segment = 0
    @State private var selectedActivity: DunnoActivity?

    private var activities: [DunnoActivity] {
        segment == 0 ? store.savedActivities : store.completedActivities
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        segmentControl

                        if activities.isEmpty {
                            emptyState
                                .transition(.opacity)
                        } else {
                            LazyVStack(spacing: 9) {
                                ForEach(activities) { activity in
                                    Button {
                                        selectedActivity = activity
                                    } label: {
                                        ActivityRowView(
                                            activity: activity,
                                            trailingSystemImage: segment == 0 ? "bookmark.fill" : "checkmark.circle.fill"
                                        )
                                    }
                                    .buttonStyle(DunnoPressableStyle())
                                    .contextMenu {
                                        if segment == 0 {
                                            Button {
                                                store.toggleSaved(activity)
                                            } label: {
                                                Label("remove from saved", systemImage: "bookmark.slash")
                                            }
                                        } else {
                                            Button(role: .destructive) {
                                                store.removeCompleted(activity)
                                            } label: {
                                                Label("remove from did it", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 15)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedActivity) { activity in
            ActivityDetailView(activity: activity)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: segment)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("library")
                .font(Font.dunnoRounded(34, weight: .bold))
                .tracking(-0.45)

            Text("Keep something for later, or look back at what you actually did.")
                .font(Font.dunno(14.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 5) {
            segmentButton("saved", symbol: "bookmark.fill", value: 0)
            segmentButton("did it", symbol: "checkmark.circle.fill", value: 1)
        }
        .padding(4)
        .dunnoGlassCapsule()
    }

    private func segmentButton(_ title: String, symbol: String, value: Int) -> some View {
        let selected = segment == value

        return Button {
            segment = value
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))

                Text(title)
                    .font(Font.dunno(14, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
            .background {
                if selected {
                    Capsule()
                        .fill(DunnoTheme.selectedControlFill(for: colorScheme))
                        .shadow(color: Color.dunnoPurple.opacity(0.14), radius: 8, y: 3)
                }
            }
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "selected" : "not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: segment == 0 ? "bookmark" : "checkmark.circle")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Color.dunnoPurple)
                .frame(width: 52, height: 52)
                .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.07))

            Text(segment == 0 ? "nothing saved yet" : "nothing finished yet")
                .font(Font.dunnoRounded(21, weight: .bold))

            Text(
                segment == 0
                    ? "Save an idea when it sounds good, just not for this exact moment."
                    : "Things you finish collect here. No streaks, points, or pressure."
            )
            .font(Font.dunno(14, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: 292)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 78)
    }
}
