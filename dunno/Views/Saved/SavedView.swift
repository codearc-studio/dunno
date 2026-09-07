import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var segment = 0
    @State private var selectedActivity: DunnoActivity?
    @State private var selectedCollectionID: UUID?
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""

    private var selectedCollection: DunnoCollection? {
        guard let selectedCollectionID else { return nil }
        return store.collections.first { $0.id == selectedCollectionID }
    }

    private var activities: [DunnoActivity] {
        if segment == 1 { return store.completedActivities }
        if let selectedCollection { return store.activities(in: selectedCollection) }
        return store.savedActivities
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        segmentControl

                        if segment == 0 {
                            collectionsBar
                        }

                        if activities.isEmpty {
                            emptyState
                                .transition(.opacity)
                        } else {
                            LazyVGrid(columns: libraryColumns, spacing: 9) {
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
                                            if !store.collections.isEmpty {
                                                Menu("collections") {
                                                    ForEach(store.collections) { collection in
                                                        let included = store.isInCollection(activity, collection: collection)
                                                        Button {
                                                            store.setActivity(activity, in: collection, included: !included)
                                                        } label: {
                                                            Label(collection.name, systemImage: included ? "checkmark" : "folder")
                                                        }
                                                    }
                                                }
                                            }

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
                    .frame(maxWidth: 1040, alignment: .leading)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
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
        .alert("new collection", isPresented: $showingNewCollection) {
            TextField("name", text: $newCollectionName)
            Button("cancel", role: .cancel) { newCollectionName = "" }
            Button("create") {
                if let collection = store.createCollection(named: newCollectionName) {
                    selectedCollectionID = collection.id
                }
                newCollectionName = ""
            }
        } message: {
            Text("Collections stay private on this device and only organize things you've saved.")
        }
        .onChange(of: store.collections) { _, collections in
            if let selectedCollectionID, !collections.contains(where: { $0.id == selectedCollectionID }) {
                self.selectedCollectionID = nil
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: segment)
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: selectedCollectionID)
    }

    private var libraryColumns: [GridItem] {
        let wide = horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
        return wide
            ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible())]
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("library")
                .font(Font.dunnoRounded(34, weight: .bold))
                .tracking(-0.45)

            Text("Keep something for later, organize the good ones, or look back at what you actually did.")
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
        .frame(maxWidth: 420, alignment: .leading)
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

    private var collectionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                collectionChip(title: "all saved", symbol: "bookmark.fill", id: nil)

                ForEach(store.collections) { collection in
                    collectionChip(title: collection.name, symbol: "folder.fill", id: collection.id)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteCollection(collection)
                            } label: {
                                Label("delete collection", systemImage: "trash")
                            }
                        }
                }

                Button {
                    showingNewCollection = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(DunnoPressableStyle())
                .dunnoGlassCapsule(interactive: true)
                .accessibilityLabel("New collection")
            }
            .padding(.vertical, 2)
        }
    }

    private func collectionChip(title: String, symbol: String, id: UUID?) -> some View {
        let selected = selectedCollectionID == id
        return Button {
            selectedCollectionID = id
        } label: {
            Label(title, systemImage: symbol)
                .font(Font.dunno(12.5, weight: .semibold))
                .foregroundStyle(selected ? DunnoTheme.purpleText(for: colorScheme) : Color.primary)
                .padding(.horizontal, 13)
                .frame(minHeight: 40)
                .contentShape(Capsule())
        }
        .buttonStyle(DunnoPressableStyle())
        .dunnoGlassCapsule(tint: selected ? Color.dunnoPurple.opacity(0.10) : .clear, interactive: true)
        .accessibilityValue(selected ? "selected" : "not selected")
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: segment == 0 ? (selectedCollection == nil ? "bookmark" : "folder") : "checkmark.circle")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Color.dunnoPurple)
                .frame(width: 52, height: 52)
                .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.07))

            Text(emptyTitle)
                .font(Font.dunnoRounded(21, weight: .bold))

            Text(emptySubtitle)
                .font(Font.dunno(14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }

    private var emptyTitle: String {
        if segment == 1 { return "nothing finished yet" }
        if let selectedCollection { return "nothing in \(selectedCollection.name) yet" }
        return "nothing saved yet"
    }

    private var emptySubtitle: String {
        if segment == 1 { return "Things you finish collect here. No streaks, points, or pressure." }
        if selectedCollection != nil { return "Add saved ideas from their context menu, or from an activity's details." }
        return "Save an idea when it sounds good, just not for this exact moment."
    }
}
