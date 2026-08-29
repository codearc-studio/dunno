import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var calibrationIndex = 0
    @State private var calibrationQueue: [DunnoActivity] = []
    @State private var welcomeVisible = false

    var body: some View {
        ZStack {
            DunnoBackground()

            VStack(spacing: 0) {
                if store.onboardingStep > 0 {
                    progressHeader
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                Group {
                    switch store.onboardingStep {
                    case 0: welcome
                    case 1: rolesStep
                    case 2: interestsStep
                    case 3: goalsStep
                    default: calibrationStep
                    }
                }
                .id(store.onboardingStep)
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.988)))
            }
        }
        .animation(reduceMotion ? nil : DunnoMotion.settle, value: store.onboardingStep)
        .onAppear {
            if store.onboardingStep == 4 && calibrationQueue.isEmpty {
                // If the app was closed during calibration, restart this tiny pass cleanly
                // instead of double-counting a partial set of answers.
                store.resetCalibration()
                calibrationQueue = makeCalibrationQueue()
                calibrationIndex = 0
            }

            guard !welcomeVisible else { return }
            if reduceMotion {
                welcomeVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.55)) { welcomeVisible = true }
            }
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            DunnoIconButton(systemName: "chevron.left", size: 40) {
                guard store.onboardingStep > 0 else { return }
                if store.onboardingStep == 4 {
                    store.resetCalibration()
                    calibrationQueue = []
                    calibrationIndex = 0
                }
                store.setOnboardingStep(store.onboardingStep - 1)
            }
            .accessibilityLabel("Back")

            GeometryReader { geo in
                Capsule()
                    .fill(Color.primary.opacity(0.065))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(DunnoTheme.primaryGradient)
                            .frame(width: geo.size.width * CGFloat(store.onboardingStep) / 4)
                    }
            }
            .frame(height: 5)

            Text("\(store.onboardingStep) of 4")
                .font(Font.dunno(11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 70 : 42)
                .accessibilityLabel("Onboarding step \(store.onboardingStep) of 4")
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 25) {
                DunnoBrandIcon(size: 132)
                    .shadow(color: Color.dunnoPurple.opacity(0.14), radius: 30, y: 13)

                DunnoWordmark(height: 42)

                VStack(spacing: 11) {
                    Text("for when you dunno\nwhat to do.")
                        .font(Font.dunnoRounded(30, weight: .bold))
                        .tracking(-0.3)
                        .multilineTextAlignment(.center)

                    Text("A few quick picks give Dunno a head start. After that, the moment matters more than a profile.")
                        .font(Font.dunno(15, weight: .medium))
                        .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.5)
                        .padding(.horizontal, 28)
                }
            }
            .opacity(welcomeVisible ? 1 : 0)
            .scaleEffect(welcomeVisible || reduceMotion ? 1 : 0.975)
            .offset(y: welcomeVisible || reduceMotion ? 0 : 10)

            Spacer()

            Button("get started") { store.setOnboardingStep(1) }
                .buttonStyle(DunnoPrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 11)
                .opacity(welcomeVisible ? 1 : 0)

            Text("no account. no personality box. skip anything you don't know yet.")
                .font(Font.dunno(11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 25)
                .opacity(welcomeVisible ? 1 : 0)
        }
    }

    private var rolesStep: some View {
        selectionPage(
            eyebrow: "about you",
            systemImage: "person.2.fill",
            title: "which sound like you?",
            subtitle: "Pick any that fit. They're starting hints, not boxes.",
            actionTitle: store.profile.roles.isEmpty ? "skip for now" : "continue"
        ) {
            LazyVGrid(columns: roleColumns, spacing: 11) {
                ForEach(DunnoTaxonomy.roles) { item in
                    roleCard(
                        item.title,
                        symbol: item.systemImage ?? "circle",
                        selected: store.profile.roles.contains(item.title)
                    ) {
                        store.toggleRole(item.title)
                    }
                }
            }
        } action: {
            store.setOnboardingStep(2)
        }
    }

    private var interestsStep: some View {
        selectionPage(
            eyebrow: "your stuff",
            systemImage: "square.grid.2x2.fill",
            title: "what are you into?",
            subtitle: "The subjects that can actually steal your attention.",
            actionTitle: store.profile.interests.isEmpty ? "skip for now" : "continue"
        ) {
            FlowLayout(spacing: 8) {
                ForEach(DunnoTaxonomy.interests) { item in
                    DunnoPill(
                        title: item.title,
                        systemImage: nil,
                        isSelected: store.profile.interests.contains(item.title)
                    ) {
                        store.toggleInterest(item.title)
                    }
                }
            }
        } action: {
            store.setOnboardingStep(3)
        }
    }

    private var goalsStep: some View {
        selectionPage(
            eyebrow: "when you're bored",
            systemImage: "sparkles",
            title: "what should dunno be good at?",
            subtitle: "A few broad lanes you tend to want. Right now can always override these.",
            actionTitle: store.profile.goals.isEmpty ? "skip for now" : "continue"
        ) {
            VStack(spacing: 9) {
                ForEach(DunnoTaxonomy.goals) { goal in
                    goalRow(
                        goal.title,
                        symbol: goal.systemImage ?? "sparkles",
                        selected: store.profile.goals.contains(goal.title)
                    ) {
                        store.toggleGoal(goal.title)
                    }
                }
            }
        } action: {
            store.resetCalibration()
            calibrationQueue = makeCalibrationQueue()
            calibrationIndex = 0
            store.setOnboardingStep(4)
        }
    }

    private var calibrationStep: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    DunnoFeatureIcon(systemName: "rectangle.stack.fill", size: 50)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("quick vibe check")
                            .font(Font.dunno(10, weight: .bold))
                            .tracking(0.35)
                            .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))

                        Text("would you actually do this?")
                            .font(Font.dunnoRounded(27, weight: .bold))
                            .tracking(-0.25)
                    }
                }

                Text("This is the one place Dunno learns from yes/no answers. Normal swipes stay about the moment.")
                    .font(Font.dunno(13.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer(minLength: 15)

            if calibrationIndex < calibrationQueue.count {
                let activity = calibrationQueue[calibrationIndex]
                ActivityCardView(activity: activity)
                    .padding(.horizontal, 23)
                    .frame(maxHeight: 458)
                    .id(activity.id)
                    .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.985)))
            } else {
                VStack(spacing: 13) {
                    DunnoBrandIcon(size: 96)
                    Text("think i've got you.")
                        .font(Font.dunnoRounded(27, weight: .bold))
                    Text("That's enough training. From here, Dunno is about what sounds good right now.")
                        .font(Font.dunno(14.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .transition(.opacity)
            }

            Spacer(minLength: 15)

            if calibrationIndex < calibrationQueue.count {
                VStack(spacing: 10) {
                    HStack(spacing: 11) {
                        calibrationButton(title: "not me", systemName: "xmark", positive: false) {
                            answerCalibration(positive: false)
                        }

                        calibrationButton(title: "i'd do this", systemName: "checkmark", positive: true) {
                            answerCalibration(positive: true)
                        }
                    }

                    Button("skip vibe check") {
                        store.resetCalibration()
                        store.finishOnboarding()
                    }
                    .font(Font.dunno(13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            } else {
                Button("show me something") { store.finishOnboarding() }
                    .buttonStyle(DunnoPrimaryButtonStyle())
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }
        }
    }

    private func calibrationButton(
        title: String,
        systemName: String,
        positive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let accent = positive ? Color.dunnoTeal : Color.dunnoRose
        let readableAccent = positive
            ? DunnoTheme.tealText(for: colorScheme)
            : DunnoTheme.roseText(for: colorScheme)

        return Button(action: action) {
            Label(title, systemImage: systemName)
                .font(Font.dunnoRounded(15, weight: .bold))
                .foregroundStyle(readableAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    if colorScheme == .light {
                        Capsule().fill(accent.opacity(positive ? 0.08 : 0.055))
                    }
                }
                .dunnoGlassCapsule(
                    tint: accent.opacity(colorScheme == .dark ? (positive ? 0.24 : 0.13) : 0.08),
                    interactive: true
                )
                .overlay {
                    Capsule().stroke(readableAccent.opacity(colorScheme == .dark ? 0.42 : 0.30), lineWidth: 0.8)
                }
        }
        .buttonStyle(DunnoPressableStyle())
    }

    private func answerCalibration(positive: Bool) {
        guard calibrationIndex < calibrationQueue.count else { return }
        let activity = calibrationQueue[calibrationIndex]
        store.recordCalibration(activity, positive: positive)

        withAnimation(reduceMotion ? nil : DunnoMotion.snappy) {
            calibrationIndex += 1
        }
    }

    private func makeCalibrationQueue() -> [DunnoActivity] {
        // Calibration should feel like a fresh taste sample, not a quiz about ideas the
        // user already finished. Fall back to the full ranked pool only if needed.
        // Calibration only needs a varied first page. Building a fully diversified queue
        // for the entire 1,000+ idea catalog here made the continue button appear frozen.
        let allRanked = store.recommendations(filters: DunnoFilters(), limit: 48)
        let freshRanked = allRanked.filter { !store.isCompleted($0) }
        let ranked = freshRanked.count >= 8 ? freshRanked : allRanked
        var picked: [DunnoActivity] = []
        var categories: Set<DunnoCategory> = []

        for activity in ranked where !categories.contains(activity.category) {
            picked.append(activity)
            categories.insert(activity.category)
            if picked.count == 8 { break }
        }

        if picked.count < 8 {
            let ids = Set(picked.map(\.id))
            picked.append(contentsOf: ranked.filter { !ids.contains($0.id) }.prefix(8 - picked.count))
        }

        return picked
    }

    private var roleColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func roleCard(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top) {
                    DunnoArtworkIcon(
                        systemName: symbol,
                        size: 46,
                        fallbackColor: Color.dunnoPurple
                    )

                    Spacer(minLength: 4)

                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selected ? Color.dunnoPurple : Color.secondary.opacity(0.35))
                }

                Text(title.lowercased())
                    .font(Font.dunnoRounded(16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(15)
            .frame(minHeight: 119)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selected ? Color.dunnoPurple.opacity(colorScheme == .dark ? 0.09 : 0.055) : Color.clear)
            }
            .dunnoSolidPanel(cornerRadius: 22, accent: selected ? Color.dunnoPurple : nil)
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "selected" : "not selected")
        .accessibilityHint("Double tap to toggle.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func goalRow(
        _ title: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                DunnoArtworkIcon(
                    systemName: symbol,
                    size: 36,
                    fallbackColor: Color.dunnoPurple
                )
                .frame(width: 40)

                Text(title.lowercased())
                    .font(Font.dunno(15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Color.dunnoPurple : Color.secondary.opacity(0.35))
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 57)
            .background {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(selected ? Color.dunnoPurple.opacity(colorScheme == .dark ? 0.085 : 0.05) : Color.clear)
            }
            .dunnoSolidPanel(cornerRadius: 19, accent: selected ? Color.dunnoPurple : nil)
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "selected" : "not selected")
        .accessibilityHint("Double tap to toggle.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func selectionPage<Content: View>(
        eyebrow: String,
        systemImage: String,
        title: String,
        subtitle: String,
        actionTitle: String,
        @ViewBuilder content: () -> Content,
        action: @escaping () -> Void
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(alignment: .top, spacing: 14) {
                    DunnoFeatureIcon(systemName: systemImage, size: 52)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(eyebrow.lowercased())
                            .font(Font.dunno(10, weight: .bold))
                            .tracking(0.35)
                            .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))

                        Text(title)
                            .font(Font.dunnoRounded(30, weight: .bold))
                            .tracking(-0.35)

                        Text(subtitle)
                            .font(Font.dunno(14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }

                content()
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
        }
        .safeAreaInset(edge: .bottom) {
            Button(actionTitle, action: action)
                .buttonStyle(DunnoPrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
        }
    }
}
