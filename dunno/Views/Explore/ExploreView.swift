import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedCategory: DunnoCategory?
    @State private var selectedActivity: DunnoActivity?
    @State private var searchText = ""
    @State private var discovery = DiscoveryCollections.empty

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
        return store.activities
            .filter { $0.category == selectedCategory }
            .sorted { store.score($0) > store.score($1) }
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
                        } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            searchField
                            searchResults
                        } else {
                            searchField
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

                                    LazyVStack(spacing: 9) {
                                        ForEach(discovery.additional.prefix(10)) { activity in
                                            activityRowButton(activity)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 15)
                    .padding(.bottom, 32)
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
            if discovery.quick.isEmpty && discovery.additional.isEmpty {
                refreshDiscovery()
            }
        }
        .onChange(of: store.shuffleSeed) { _, _ in
            refreshDiscovery()
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: selectedCategory)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("explore")
                .font(Font.dunnoRounded(34, weight: .bold))
                .tracking(-0.45)

            Text(
                selectedCategory == nil
                    ? "Browse a lane when you know the vibe, just not the thing."
                    : "A focused set of ideas from this lane."
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

            TextField("search ideas", text: $searchText)
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
        .padding(.horizontal, 20)
    }

    private var searchMatches: [DunnoActivity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }

        return store.activities
            .filter { activity in
                let searchable = ([
                    activity.title,
                    activity.hook,
                    activity.description,
                    activity.category.rawValue
                ] + activity.tags + activity.goals)
                    .joined(separator: " ")
                    .lowercased()
                return searchable.localizedStandardContains(query)
            }
            .sorted { store.score($0) > store.score($1) }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            DunnoSectionHeader(
                title: searchMatches.isEmpty ? "no matches" : "results",
                subtitle: searchMatches.isEmpty ? "Try a broader word or category." : "\(searchMatches.count) ideas"
            )

            if !searchMatches.isEmpty {
                LazyVStack(spacing: 9) {
                    ForEach(searchMatches) { activity in
                        activityRowButton(activity)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
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

    private var categoryColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
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
                    Text("\(categoryActivities.count) ideas")
                        .font(Font.dunno(13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVStack(spacing: 9) {
                ForEach(categoryActivities) { activity in
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
        let ranked = store.recommendations(filters: DunnoFilters())

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
