import SwiftUI

struct ExploreView: View {
    var isActive = true

    @EnvironmentObject private var store: DunnoStore
    @EnvironmentObject private var sharedWithYou: DunnoSharedWithYouStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedCategory: DunnoCategory?
    @State private var selectedOccasion: DunnoOccasion?
    @State private var selectedActivity: DunnoActivity?
    @State private var searchText = ""
    @State private var searchMatches: [DunnoActivity] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var discovery = DiscoveryCollections.empty
    @State private var discoveryNeedsRefresh = false

    private struct DiscoveryCollections {
        var quick: [DunnoActivity]
        var lowKey: [DunnoActivity]
        var withSomeone: [DunnoActivity]
        var getOut: [DunnoActivity]
        var additional: [DunnoActivity]

        static let empty = DiscoveryCollections(quick: [], lowKey: [], withSomeone: [], getOut: [], additional: [])
    }

    private var categoryActivities: [DunnoActivity] {
        guard let selectedCategory else { return [] }
        // Explore is intentional browsing, not the recommendation feed. Long-term
        // "show me less" feedback and Never Repeat only affect suggestions; users can
        // still deliberately find any idea here, including something they have done.
        return ranked(store.activities.filter { $0.category == selectedCategory })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        header

                        if let selectedCategory {
                            categoryDetail(selectedCategory)
                                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.99)))
                        } else if let selectedOccasion {
                            occasionDetail(selectedOccasion)
                                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.99)))
                        } else {
                            // Keep one stable TextField in the hierarchy while searchText changes.
                            // Previously the first typed character moved searchField into another
                            // conditional branch, which recreated it and dropped keyboard focus.
                            searchField

                            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                searchResults
                            } else {
                                sharedWithYouShelf
                                occasionGrid
                                categoryGrid

                                discoverySection(
                                    "quick stuff",
                                    subtitle: "Ideas that fit into a small gap.",
                                    activities: discovery.quick
                                )

                                discoverySection(
                                    "low-key",
                                    subtitle: "When you want something without making a whole event of it.",
                                    activities: discovery.lowKey
                                )

                                discoverySection(
                                    "with someone",
                                    subtitle: "Better with another person around.",
                                    activities: discovery.withSomeone
                                )

                                discoverySection(
                                    "get out",
                                    subtitle: "A reason to leave the room for a bit.",
                                    activities: discovery.getOut
                                )

                                if !discovery.additional.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        DunnoSectionHeader(title: "a few more")

                                        LazyVGrid(columns: activityColumns, spacing: 9) {
                                            ForEach(discovery.additional.prefix(isWideLayout ? 12 : 10)) { activity in
                                                activityRowButton(activity)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 1120, alignment: .leading)
                    .padding(.top, 15)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
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
        .onAppear {
            if isActive {
                sharedWithYou.refresh()
                if discovery.quick.isEmpty && discovery.additional.isEmpty {
                    refreshDiscovery()
                }
            } else {
                discoveryNeedsRefresh = true
            }
        }
        .onChange(of: store.shuffleSeed) { _, _ in
            guard isActive else {
                discoveryNeedsRefresh = true
                return
            }
            refreshDiscovery()
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scheduleSearch(searchText, debounce: false)
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            sharedWithYou.refresh()
            if discoveryNeedsRefresh || discovery.quick.isEmpty || discovery.additional.isEmpty {
                discoveryNeedsRefresh = false
                refreshDiscovery()
            }
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scheduleSearch(searchText, debounce: false)
            }
        }
        .onChange(of: searchText) { _, query in
            scheduleSearch(query)
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: selectedCategory)
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: selectedOccasion)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("explore")
                .font(Font.dunnoRounded(34, weight: .bold))
                .tracking(-0.45)

            Text(
                selectedCategory != nil || selectedOccasion != nil
                    ? "A focused set of ideas for this lane."
                    : "Search naturally, pick an occasion, or browse a category."
            )
            .font(Font.dunno(14.5, weight: .medium))
            .foregroundStyle(.secondary)
            .lineSpacing(2)
        }
        .padding(.horizontal, 20)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("try ‘creative under 20 minutes’", text: $searchText)
                .font(Font.dunno(14.5, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .dunnoGlassPanel(cornerRadius: 17, interactive: true)
        .frame(maxWidth: isWideLayout ? 700 : .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var searchResults: some View {
        let matches = searchMatches

        return VStack(alignment: .leading, spacing: 12) {
            DunnoSectionHeader(
                title: matches.isEmpty ? "no matches" : "results",
                subtitle: matches.isEmpty ? "Try a broader word or category." : "\(matches.count) ideas"
            )

            if !matches.isEmpty {
                LazyVGrid(columns: activityColumns, spacing: 9) {
                    ForEach(matches) { activity in
                        activityRowButton(activity)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }


    private func scheduleSearch(_ query: String, debounce: Bool = true) {
        searchTask?.cancel()
        searchTask = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchMatches = []
            return
        }

        searchTask = Task { @MainActor in
            if debounce {
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled else { return }
            }

            let matches = DunnoSearchEngine.ranked(
                query: trimmed,
                activities: store.activities,
                baseScore: { store.score($0) },
                maxResults: 100
            )
            guard !Task.isCancelled,
                  searchText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
            searchMatches = matches
        }
    }


    @ViewBuilder
    private var sharedWithYouShelf: some View {
        if !sharedWithYou.items.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                DunnoSectionHeader(
                    title: "shared with you",
                    subtitle: "Ideas people sent you in Messages."
                )
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(sharedWithYou.items.prefix(8)) { item in
                            DunnoSharedWithYouCard(item: item) {
                                selectedActivity = item.activity
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var occasionGrid: some View {
        VStack(alignment: .leading, spacing: 13) {
            DunnoSectionHeader(
                title: "right now-ish",
                subtitle: "Curated ways into the same Dunno library."
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(DunnoOccasion.all) { occasion in
                        Button {
                            selectedOccasion = occasion
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: occasion.symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.dunnoPurple)
                                    .frame(width: 42, height: 42)
                                    .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.08))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(occasion.title)
                                        .font(Font.dunnoRounded(16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(occasion.subtitle)
                                        .font(Font.dunno(11.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .padding(15)
                            .frame(width: 205, alignment: .leading)
                            .frame(minHeight: 154, alignment: .leading)
                            .dunnoSolidPanel(cornerRadius: 22, accent: Color.dunnoPurple)
                        }
                        .buttonStyle(DunnoPressableStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 13) {
            DunnoSectionHeader(title: "categories")
                .padding(.horizontal, 20)

            LazyVGrid(columns: categoryColumns, spacing: 10) {
                ForEach(DunnoCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        categoryCard(category)
                    }
                    .buttonStyle(DunnoPressableStyle())
                    .accessibilityLabel("\(category.rawValue), \(store.activities.filter { $0.category == category }.count) ideas")
                    .accessibilityHint("Double tap to browse this category.")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var isWideLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var categoryColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        if isWideLayout {
            return Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        }

        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var activityColumns: [GridItem] {
        isWideLayout
            ? [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
            : [GridItem(.flexible())]
    }

    private func categoryCard(_ category: DunnoCategory) -> some View {
        let accent = DunnoTheme.categoryAccent(category)
        let count = store.activities.filter { $0.category == category }.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                DunnoArtworkIcon(
                    systemName: category.symbol,
                    size: 46,
                    fallbackColor: accent
                )

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                    .padding(.top, 3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(category.rawValue.lowercased())
                    .font(Font.dunnoRounded(16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(count) ideas")
                    .font(Font.dunno(11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 22, accent: accent)
    }

    private func categoryDetail(_ category: DunnoCategory) -> some View {
        let accent = DunnoTheme.categoryAccent(category)
        let activities = categoryActivities

        return VStack(alignment: .leading, spacing: 18) {
            Button {
                selectedCategory = nil
            } label: {
                Label("all categories", systemImage: "chevron.left")
                    .font(Font.dunno(13, weight: .semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 39)
                    .dunnoGlassCapsule(interactive: true)
            }
            .buttonStyle(DunnoPressableStyle())

            HStack(spacing: 14) {
                DunnoArtworkIcon(
                    systemName: category.symbol,
                    size: 60,
                    fallbackColor: accent
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue.lowercased())
                        .font(Font.dunnoRounded(27, weight: .bold))
                        .tracking(-0.3)
                    Text("\(activities.count) ideas")
                        .font(Font.dunno(13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: activityColumns, spacing: 9) {
                ForEach(activities) { activity in
                    activityRowButton(activity)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func occasionDetail(_ occasion: DunnoOccasion) -> some View {
        let activities = store.activities
            .filter(occasion.matches)
            .map { (activity: $0, score: occasion.score($0) + store.score($0) * 0.08) }
            .sorted { $0.score > $1.score }
            .map(\.activity)

        return VStack(alignment: .leading, spacing: 18) {
            Button {
                selectedOccasion = nil
            } label: {
                Label("all occasions", systemImage: "chevron.left")
                    .font(Font.dunno(13, weight: .semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 39)
                    .dunnoGlassCapsule(interactive: true)
            }
            .buttonStyle(DunnoPressableStyle())

            HStack(spacing: 14) {
                Image(systemName: occasion.symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Color.dunnoPurple)
                    .frame(width: 60, height: 60)
                    .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.09))

                VStack(alignment: .leading, spacing: 4) {
                    Text(occasion.title)
                        .font(Font.dunnoRounded(27, weight: .bold))
                        .tracking(-0.3)
                    Text(occasion.subtitle)
                        .font(Font.dunno(13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            LazyVGrid(columns: activityColumns, spacing: 9) {
                ForEach(activities) { activity in
                    activityRowButton(activity)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func discoverySection(_ title: String, subtitle: String, activities: [DunnoActivity]) -> some View {
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                DunnoSectionHeader(title: title, subtitle: subtitle)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(activities.prefix(8)) { activity in
                            Button {
                                selectedActivity = activity
                            } label: {
                                ExploreMiniCard(activity: activity)
                            }
                            .buttonStyle(DunnoPressableStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func refreshDiscovery() {
        // Ranking is intentionally computed once per meaningful recommendation change.
        // Previously each section recursively recomputed the full O(n²) ranking several
        // times during every body evaluation, which made Explore noticeably stutter.
        let ranked = store.recommendations(filters: DunnoFilters(), limit: 80)

        let quick = Array(ranked.filter { $0.maxMinutes <= 20 }.prefix(8))
        var used = Set(quick.map(\.id))

        let lowRanked = ranked.filter { $0.energy.level <= DunnoEnergy.chill.level }
        let lowKey = Array(lowRanked.filter { !used.contains($0.id) }.prefix(8))
        used.formUnion(lowKey.map(\.id))

        let people: [DunnoSocial] = [.friend, .partner, .family, .group]
        let withSomeone = Array(
            ranked.filter { activity in
                !used.contains(activity.id) && people.contains { activity.social.contains($0) }
            }.prefix(8)
        )
        used.formUnion(withSomeone.map(\.id))

        let getOut = Array(
            ranked.filter { activity in
                !used.contains(activity.id) &&
                (activity.contexts.contains(.out) || activity.contexts.contains(.outside))
            }.prefix(8)
        )
        used.formUnion(getOut.map(\.id))

        let additional = ranked.filter { !used.contains($0.id) }

        discovery = DiscoveryCollections(
            quick: quick,
            lowKey: lowKey,
            withSomeone: withSomeone,
            getOut: getOut,
            additional: additional
        )
    }

    private func activityRowButton(_ activity: DunnoActivity) -> some View {
        Button {
            selectedActivity = activity
        } label: {
            ActivityRowView(activity: activity)
        }
        .buttonStyle(DunnoPressableStyle())
    }

    /// Score each activity once before sorting. Calling `store.score` from both sides of
    /// the comparator recalculated the full preference model O(n log n) times while typing.
    private func ranked(_ activities: [DunnoActivity]) -> [DunnoActivity] {
        activities
            .map { (activity: $0, score: store.score($0)) }
            .sorted { $0.score > $1.score }
            .map(\.activity)
    }

    private func recommendations(
        maxMinutes: Int? = nil,
        energy: DunnoEnergy? = nil,
        context: DunnoContext? = nil,
        social: DunnoSocial? = nil
    ) -> [DunnoActivity] {
        store.recommendations(
            filters: DunnoFilters(
                maxMinutes: maxMinutes,
                energy: energy,
                context: context,
                social: social
            )
        )
    }
}


private struct DunnoSharedWithYouCard: View {
    let item: DunnoSharedWithYouItem
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { DunnoTheme.categoryAccent(item.activity.category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        DunnoArtworkIcon(
                            systemName: item.mode == .together ? "person.2.fill" : item.activity.category.symbol,
                            size: 40,
                            fallbackColor: accent
                        )

                        Spacer(minLength: 8)

                        Label(item.activity.durationLabel, systemImage: "clock")
                            .font(Font.dunno(10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        if item.mode == .together {
                            Text("do this with me")
                                .font(Font.dunno(9.5, weight: .bold))
                                .tracking(0.35)
                                .foregroundStyle(Color.dunnoPurple)
                        }

                        Text(item.activity.title)
                            .font(Font.dunnoRounded(17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(item.activity.hook)
                            .font(Font.dunno(11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(DunnoPressableStyle())

            DunnoSharedWithYouAttributionView(highlight: item.highlight, maxWidth: 220)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(width: 250, alignment: .leading)
        .frame(minHeight: 188, alignment: .topLeading)
        .dunnoSolidPanel(cornerRadius: 23, accent: accent)
        .accessibilityElement(children: .contain)
    }
}

private struct ExploreMiniCard: View {
    let activity: DunnoActivity

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var textAccent: Color { DunnoTheme.categoryTextAccent(activity.category, scheme: colorScheme) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(DunnoTheme.cardSurface(for: colorScheme))

            RadialGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.10 : 0.05),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 145
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DunnoArtworkIcon(
                        systemName: activity.category.symbol,
                        size: 38,
                        fallbackColor: accent
                    )

                    Spacer()

                    Text(activity.category.rawValue.lowercased())
                        .font(Font.dunno(9, weight: .bold))
                        .tracking(0.25)
                        .foregroundStyle(textAccent)
                }

                Spacer(minLength: 6)

                Text(activity.title)
                    .font(Font.dunnoRounded(17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)

                Label(activity.durationLabel, systemImage: "clock")
                    .font(Font.dunno(11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(15)
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 260 : 210, alignment: .leading)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 220 : 158, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.055), lineWidth: 0.75)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.035), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(activity.title). \(activity.category.rawValue). \(activity.durationLabel).")
        .accessibilityHint("Double tap to open details.")
    }
}
