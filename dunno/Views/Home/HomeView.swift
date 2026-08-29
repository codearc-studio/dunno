import SwiftUI
import Foundation
import UIKit

struct HomeView: View {
    var isActive = true

    private enum SwipeIntent {
        case notNow
        case doIt
    }

    private enum UndoKind {
        case notNow
        case showLess
    }

    private struct UndoState {
        let token = UUID()
        let activity: DunnoActivity
        let kind: UndoKind
    }

    @EnvironmentObject private var store: DunnoStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var queue: [DunnoActivity] = []
    @State private var dragOffset: CGSize = .zero
    @State private var selectedActivity: DunnoActivity?
    @State private var selectedWasDoIt = false
    @State private var showingFilters = false
    @State private var sessionDismissedIDs: Set<String> = []
    @State private var undoState: UndoState?
    @State private var thresholdIntent: SwipeIntent?
    @State private var isTransitioning = false
    @State private var pendingReplacement: DunnoActivity?
    @State private var showingReplaceConfirmation = false
    @State private var lastRecordedActivityID: String?

    private let swipeThreshold: CGFloat = 96

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                homeLayout
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedActivity) { activity in
            ActivityDetailView(activity: activity, startsNow: selectedWasDoIt)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFilters) {
            FiltersView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            store.expireCurrentActivityIfNeeded()
            store.expireFiltersIfNeeded()
            if queue.isEmpty { reloadQueue() }
        }
        .onChange(of: store.shuffleSeed) { _, _ in
            reloadQueue()
        }
        .onChange(of: store.filters) { _, _ in
            sessionDismissedIDs.removeAll()
            clearUndo()
            reloadQueue()
        }
        .onChange(of: store.currentActivityID) { _, newID in
            guard let newID, !isTransitioning else { return }
            if queue.contains(where: { $0.id == newID }) {
                queue.removeAll { $0.id == newID }
                refillQueueIfNeeded()
                recordFirstIfNeeded()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                store.expireCurrentActivityIfNeeded()
                store.expireFiltersIfNeeded()
                recordFirstIfNeeded()
            }
        }
        .onChange(of: showingFilters) { _, showing in
            if !showing { recordFirstIfNeeded() }
        }
        .onChange(of: selectedActivity) { _, activity in
            if activity == nil { recordFirstIfNeeded() }
        }
        .alert("Switch what you're doing?", isPresented: $showingReplaceConfirmation, presenting: pendingReplacement) { activity in
            Button("Keep current", role: .cancel) {
                pendingReplacement = nil
            }
            Button("Switch to this") {
                pendingReplacement = nil
                commitChoose(activity)
            }
        } message: { activity in
            if let current = store.currentActivity {
                Text("You're already doing “\(current.title)”. Switch to “\(activity.title)”? The current one won't be marked done.")
            } else {
                Text("Start “\(activity.title)”? ")
            }
        }
    }

    @ViewBuilder
    private var homeLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    rightNowSummary
                    cardStack

                    if let undoState {
                        undoToast(undoState)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    controls
                }
                .padding(.horizontal, 20)
                .padding(.top, 7)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        } else {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 7)

                rightNowSummary
                    .padding(.horizontal, 20)
                    .padding(.top, 13)

                Spacer(minLength: 16)

                cardStack
                    .padding(.horizontal, 20)

                Spacer(minLength: 14)

                if let undoState {
                    undoToast(undoState)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 9)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                controls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 13)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            DunnoWordmark(height: 29)

            Spacer()

            Button {
                sessionDismissedIDs.removeAll()
                clearUndo()
                store.shuffle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                shuffleIcon
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .dunnoGlassCapsule(interactive: true)
            }
            .buttonStyle(DunnoPressableStyle())
            .disabled(isTransitioning)
            .accessibilityLabel("Give me different ideas")
        }
    }

    @ViewBuilder
    private var shuffleIcon: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "arrow.clockwise")
                .symbolEffect(.rotate, value: store.shuffleSeed)
        } else {
            Image(systemName: "arrow.clockwise")
        }
    }

    private var rightNowSummary: some View {
        Button {
            showingFilters = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.filters.isActive ? Color.dunnoPurple : .secondary)

                Text("right now")
                    .font(Font.dunno(13, weight: .semibold))
                    .foregroundStyle(.primary)

                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 14)

                Text(filterSummary)
                    .font(Font.dunno(13, weight: .medium))
                    .foregroundStyle(store.filters.isActive ? Color.dunnoPurple : .secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 43)
            .dunnoGlassCapsule(
                tint: store.filters.isActive ? Color.dunnoPurple.opacity(0.09) : nil,
                interactive: true
            )
        }
        .buttonStyle(DunnoPressableStyle())
        .disabled(isTransitioning)
        .accessibilityLabel("Right now, \(filterSummary)")
        .accessibilityHint("Double tap to change time, energy, place, or who you are with.")
    }

    private var filterSummary: String {
        var parts: [String] = []

        if let max = store.filters.maxMinutes {
            parts.append(max >= 120 ? "I've got time" : "\(max) min")
        }
        if let energy = store.filters.energy { parts.append(energy.shortLabel) }
        if let context = store.filters.context { parts.append(context.rawValue) }
        if let social = store.filters.social { parts.append(social.rawValue) }

        return parts.isEmpty ? "tell dunno what's up" : parts.joined(separator: " · ")
    }

    private var cardStack: some View {
        ZStack {
            if queue.isEmpty {
                emptyState
            } else {
                ForEach(Array(queue.prefix(3).indices).reversed(), id: \.self) { index in
                    let activity = queue[index]
                    let progress = max(leftSwipeProgress, rightSwipeProgress)
                    let backScale = 1 - CGFloat(index) * 0.028 + (index == 1 ? progress * 0.018 : 0)
                    let backYOffset = -CGFloat(index) * 10 + (index == 1 ? progress * 7 : 0)
                    let backXOffset = CGFloat(index) * 4

                    ActivityCardView(activity: activity, showsContent: index == 0)
                        .id(activity.id)
                        .overlay {
                            if index == 0 { swipeCardTint }
                        }
                        .overlay(alignment: .topTrailing) {
                            if index == 0 {
                                quickActions(for: activity)
                                    .padding(19)
                            }
                        }
                        .scaleEffect(index == 0 ? frontCardScale : backScale)
                        .offset(
                            x: index == 0 ? dragOffset.width : backXOffset,
                            y: index == 0 ? dragOffset.height * 0.055 : backYOffset
                        )
                        .rotationEffect(.degrees(rotationForCard(index: index)))
                        .opacity(index == 0 ? 1 : 0.90 - Double(index) * 0.12 + Double(progress) * (index == 1 ? 0.08 : 0))
                        .zIndex(Double(3 - index))
                        .onTapGesture {
                            guard index == 0, !isTransitioning else { return }
                            selectedWasDoIt = store.currentActivityID == activity.id
                            selectedActivity = activity
                        }
                        .gesture(dragGesture(for: activity), including: index == 0 && !isTransitioning ? .all : .none)
                        .allowsHitTesting(index == 0 && !isTransitioning)
                        .accessibilityAction(named: Text("not now")) {
                            guard index == 0, !isTransitioning else { return }
                            notNow(activity)
                        }
                        .accessibilityAction(named: Text("do it")) {
                            guard index == 0, !isTransitioning else { return }
                            requestChoose(activity)
                        }
                        .accessibilityAction(named: Text("save for later")) {
                            guard index == 0, !isTransitioning, !store.isCompleted(activity) else { return }
                            store.toggleSaved(activity)
                        }
                        .accessibilityAction(named: Text("show me less like this")) {
                            guard index == 0, !isTransitioning else { return }
                            store.showLessLikeThis(activity)
                            sessionDismissedIDs.insert(activity.id)
                            dismissCard(direction: -1, undoAfter: UndoState(activity: activity, kind: .showLess), rerankAfter: true)
                        }
                        .accessibilityHidden(index != 0)
                }
            }
        }
        .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 560 : 440)
        // Drag-driven transforms should track the finger directly. Animating the entire
        // stack on every gesture update made the card feel delayed and forced SwiftUI to
        // continuously interpolate expensive effects. Snap/dismiss animations are applied
        // explicitly in the gesture handlers instead.
    }

    private var frontCardScale: CGFloat {
        guard !reduceMotion else { return 1 }
        let progress = max(leftSwipeProgress, rightSwipeProgress)
        return 1 - progress * 0.012
    }

    private func rotationForCard(index: Int) -> Double {
        if index == 0 {
            guard !reduceMotion else { return 0 }
            return max(-5.5, min(5.5, Double(dragOffset.width / 34)))
        }
        return Double(index) * -0.55
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: store.filters.isActive ? "slider.horizontal.3" : "rectangle.stack")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.dunnoPurple)
                .frame(width: 52, height: 52)
                .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.08))

            Text(store.filters.isActive ? "Nothing fits all of that" : "That's the round")
                .font(Font.dunnoRounded(22, weight: .bold))

            Text(
                store.filters.isActive
                    ? "Loosen one part of Right now and Dunno will try again. Your choices won't be quietly ignored."
                    : "You've moved through everything in this mix. Shuffle and Dunno will deal you a fresh order."
            )
            .font(Font.dunno(14, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .frame(maxWidth: 300)

            if store.filters.isActive {
                HStack(spacing: 10) {
                    Button("change it") { showingFilters = true }
                        .font(Font.dunno(14, weight: .semibold))
                        .padding(.horizontal, 15)
                        .frame(height: 42)
                        .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.10), interactive: true)
                        .buttonStyle(DunnoPressableStyle())

                    Button("clear") { store.filters = DunnoFilters() }
                        .font(Font.dunno(14, weight: .semibold))
                        .padding(.horizontal, 15)
                        .frame(height: 42)
                        .dunnoGlassCapsule(interactive: true)
                        .buttonStyle(DunnoPressableStyle())
                }
            } else {
                Button {
                    sessionDismissedIDs.removeAll()
                    clearUndo()
                    store.shuffle()
                } label: {
                    Label("mix it up", systemImage: "arrow.clockwise")
                        .font(Font.dunno(14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.08), interactive: true)
                }
                .buttonStyle(DunnoPressableStyle())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 382)
        .padding(24)
    }

    @ViewBuilder
    private var swipeCardTint: some View {
        let progress = max(leftSwipeProgress, rightSwipeProgress)

        if progress > 0.01 {
            let tint = rightSwipeProgress > 0 ? DunnoTheme.positiveAction : DunnoTheme.negativeAction

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(tint.opacity(0.025 + Double(progress) * 0.19))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(tint.opacity(0.04 + Double(progress) * 0.25), lineWidth: 0.9)
                }
                .allowsHitTesting(false)
        }
    }

    private func quickActions(for activity: DunnoActivity) -> some View {
        Menu {
            if !store.isCompleted(activity) {
                Button {
                    store.toggleSaved(activity)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        store.isSaved(activity) ? "remove from saved" : "save for later",
                        systemImage: store.isSaved(activity) ? "bookmark.slash" : "bookmark"
                    )
                }

                Divider()
            }

            Button {
                guard !isTransitioning else { return }
                store.showLessLikeThis(activity)
                sessionDismissedIDs.insert(activity.id)
                clearUndo()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismissCard(direction: -1, undoAfter: UndoState(activity: activity, kind: .showLess), rerankAfter: true)
            } label: {
                Label("show me less like this", systemImage: "eye.slash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(DunnoTheme.elevatedSurface(for: colorScheme).opacity(0.92))
                }
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.055), lineWidth: 0.7)
                }
                .contentShape(Circle())
        }
        .disabled(isTransitioning)
        .accessibilityLabel("More options")
    }

    private var controls: some View {
        HStack(spacing: 11) {
            decisionButton(
                title: "not now",
                systemName: "xmark",
                activeProgress: leftSwipeProgress,
                positive: false
            ) {
                guard let activity = queue.first else { return }
                notNow(activity)
            }

            decisionButton(
                title: "do it",
                systemName: "checkmark",
                activeProgress: rightSwipeProgress,
                positive: true
            ) {
                guard let activity = queue.first else { return }
                requestChoose(activity)
            }
        }
        .disabled(isTransitioning || queue.isEmpty)
    }

    private func decisionButton(
        title: String,
        systemName: String,
        activeProgress: CGFloat,
        positive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let progress = Double(activeProgress)
        let accent = positive ? DunnoTheme.positiveAction : DunnoTheme.negativeAction

        return Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))

                Text(title)
                    .font(Font.dunnoRounded(16, weight: .bold))
            }
            .foregroundStyle(
                activeProgress > 0.16
                    ? (colorScheme == .dark
                        ? Color.white
                        : (positive ? DunnoTheme.tealText(for: colorScheme) : DunnoTheme.roseText(for: colorScheme)))
                    : Color.primary
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 57)
            // Keep the Liquid Glass material itself stable while dragging. Rebuilding a
            // dynamically tinted glass shader every gesture frame was one of the largest
            // sources of hitching. The color wash above it still gives vivid feedback.
            .dunnoGlassCapsule(interactive: true)
            .overlay {
                Capsule()
                    .fill(accent.opacity(progress * 0.38))
                    .allowsHitTesting(false)
            }
            .overlay {
                Capsule()
                    .stroke(
                        activeProgress > 0.02
                            ? accent.opacity(0.20 + progress * 0.60)
                            : Color.primary.opacity(0.055),
                        lineWidth: activeProgress > 0.62 ? 1.05 : 0.75
                    )
            }
            .shadow(color: accent.opacity(progress * 0.24), radius: 12, y: 5)
            .scaleEffect(reduceMotion ? 1 : 1 + activeProgress * 0.014)
        }
        .buttonStyle(DunnoPressableStyle())
        .accessibilityLabel(title)
        .accessibilityHint(positive ? "Start this idea now." : "Skip this idea for this session.")
    }

    private func undoToast(_ state: UndoState) -> some View {
        HStack(spacing: 9) {
            Image(systemName: state.kind == .showLess ? "eye.slash" : "arrow.uturn.backward")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(state.kind == .showLess ? "showing less like this" : state.activity.title)
                .font(Font.dunno(13, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("undo") {
                if state.kind == .showLess {
                    store.restoreSuggestion(state.activity, refresh: false)
                }
                sessionDismissedIDs.remove(state.activity.id)
                queue.removeAll { $0.id == state.activity.id }
                queue.insert(state.activity, at: 0)
                dragOffset = .zero
                // Undo returns to the same presentation; don't count it as a brand-new
                // exposure and accidentally penalize an idea the user just brought back.
                lastRecordedActivityID = state.activity.id
                clearUndo()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(Font.dunno(13, weight: .bold))
            .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .dunnoGlassCapsule(tint: Color.dunnoPurple.opacity(0.035))
    }

    private var leftSwipeProgress: CGFloat {
        min(max(-dragOffset.width / swipeThreshold, 0), 1)
    }

    private var rightSwipeProgress: CGFloat {
        min(max(dragOffset.width / swipeThreshold, 0), 1)
    }

    private func dragGesture(for activity: DunnoActivity) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isTransitioning else { return }
                dragOffset = value.translation
                updateThresholdFeedback(for: value.translation.width)
            }
            .onEnded { value in
                let projectedWidth = value.predictedEndTranslation.width
                let committedWidth = abs(projectedWidth) > abs(value.translation.width)
                    ? projectedWidth
                    : value.translation.width

                thresholdIntent = nil

                if committedWidth < -swipeThreshold {
                    notNow(activity)
                } else if committedWidth > swipeThreshold {
                    requestChoose(activity)
                } else {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : DunnoMotion.interactive) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func updateThresholdFeedback(for width: CGFloat) {
        let nextIntent: SwipeIntent?
        if width <= -swipeThreshold {
            nextIntent = .notNow
        } else if width >= swipeThreshold {
            nextIntent = .doIt
        } else {
            nextIntent = nil
        }

        guard nextIntent != thresholdIntent else { return }
        thresholdIntent = nextIntent

        if nextIntent != nil {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.68)
        }
    }

    private func notNow(_ activity: DunnoActivity) {
        guard !isTransitioning else { return }
        store.skipForNow(activity)
        sessionDismissedIDs.insert(activity.id)
        dismissCard(
            direction: -1,
            undoAfter: UndoState(activity: activity, kind: .notNow)
        )
    }

    private func requestChoose(_ activity: DunnoActivity) {
        guard !isTransitioning else { return }

        if let current = store.currentActivity, current.id != activity.id {
            pendingReplacement = activity
            showingReplaceConfirmation = true
            thresholdIntent = nil
            withAnimation(reduceMotion ? nil : DunnoMotion.interactive) {
                dragOffset = .zero
            }
            return
        }

        commitChoose(activity)
    }

    private func commitChoose(_ activity: DunnoActivity) {
        guard !isTransitioning else { return }
        clearUndo()
        sessionDismissedIDs.insert(activity.id)
        dismissCard(direction: 1, openAfter: activity, startActivity: activity)
    }

    private func dismissCard(
        direction: CGFloat,
        openAfter activity: DunnoActivity? = nil,
        undoAfter undo: UndoState? = nil,
        rerankAfter: Bool = false,
        startActivity: DunnoActivity? = nil
    ) {
        guard !isTransitioning else { return }
        isTransitioning = true

        if let startActivity {
            // Start only after the transition lock is raised. Otherwise the store's
            // currentActivityID change can remove the front card before it animates away.
            store.chooseForNow(startActivity)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.32, bounce: 0.04)) {
            dragOffset = CGSize(width: direction * 720, height: reduceMotion ? 0 : 14)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.10 : 0.20)) {
            advance()

            if rerankAfter {
                reloadQueue()
            } else if activity == nil {
                recordFirstIfNeeded()
            }

            if let undo { showUndo(undo) }

            if let activity {
                selectedWasDoIt = true
                selectedActivity = activity
            }

            isTransitioning = false
        }
    }

    private func advance() {
        dragOffset = .zero
        thresholdIntent = nil
        if !queue.isEmpty { queue.removeFirst() }
        refillQueueIfNeeded()
    }

    private func refillQueueIfNeeded() {
        guard queue.count < 4 else { return }

        let existing = Set(queue.map(\.id))
        let rankingLimit = min(store.activities.count, sessionDismissedIDs.count + 32)
        let more = store.recommendations(limit: rankingLimit).filter {
            !existing.contains($0.id) && !sessionDismissedIDs.contains($0.id)
        }
        queue.append(contentsOf: more.prefix(8))
    }

    private func reloadQueue() {
        thresholdIntent = nil
        isTransitioning = false
        let rankingLimit = min(store.activities.count, sessionDismissedIDs.count + 32)
        queue = Array(
            store.recommendations(limit: rankingLimit)
                .filter { !sessionDismissedIDs.contains($0.id) }
                .prefix(16)
        )
        dragOffset = .zero
        lastRecordedActivityID = nil
        recordFirstIfNeeded()
    }

    private func recordFirstIfNeeded() {
        guard isActive, !showingFilters, selectedActivity == nil else { return }
        guard let first = queue.first, first.id != lastRecordedActivityID else { return }
        store.recordShown(first)
        lastRecordedActivityID = first.id
    }

    private func showUndo(_ state: UndoState) {
        withAnimation(reduceMotion ? nil : DunnoMotion.snappy) {
            undoState = state
        }

        let token = state.token
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard undoState?.token == token else { return }
            clearUndo()
        }
    }

    private func clearUndo() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            undoState = nil
        }
    }

}
