import SwiftUI
import CoreLocation
import TipKit
import UIKit

struct ActivityDetailView: View {
    @EnvironmentObject private var store: DunnoStore
    @EnvironmentObject private var nearby: DunnoNearbyService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let activity: DunnoActivity
    var startsNow: Bool = false
    var sharedMode: DunnoShareMode? = nil

    @State private var showingReplaceConfirmation = false
    @State private var showingRemoveConfirmation = false
    @State private var showingShare = false
    @State private var showingNote = false
    @State private var showingSwitchPicker = false

    private var isCurrent: Bool { store.currentActivityID == activity.id }
    private var isCompleted: Bool { store.isCompleted(activity) }
    private var accent: Color { DunnoTheme.categoryAccent(activity.category) }
    private var textAccent: Color { DunnoTheme.categoryTextAccent(activity.category, scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        if let sharedMode {
                            sharedStatus(sharedMode)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        if isCurrent {
                            currentStatus
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            doingNowControls
                            TipView(DunnoMinimizeTip())
                        }

                        hero
                        descriptionBlock
                        metadata
                        if nearbyKind != nil {
                            nearbySection
                        }
                        steps
                        if isCompleted || !store.note(for: activity).isEmpty {
                            privateNoteSection
                        }
                        tags
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 21)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(activity.category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share activity")

                    trailingToolbar
                }
            }
            .safeAreaInset(edge: .bottom) {
                primaryAction
                    .frame(maxWidth: 720)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showingShare) {
            DunnoShareView(activity: activity)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNote) {
            DunnoActivityNoteEditor(activity: activity, existingNote: store.note(for: activity))
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSwitchPicker) {
            DunnoSwitchActivityPicker(currentActivity: activity) { option in
                store.beginCurrentActivity(option)
                showingSwitchPicker = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { @MainActor in
                    await Task.yield()
                    dismiss()
                }
            }
            .environmentObject(store)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task(id: nearbyTaskID) {
            guard nearbyKind != nil, nearby.isEnabled, nearby.isAuthorized else { return }
            await nearby.loadPlaces(for: activity)
        }
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: isCurrent)
        .animation(reduceMotion ? nil : DunnoMotion.snappy, value: isCompleted)
        .alert("Switch what you're doing?", isPresented: $showingReplaceConfirmation) {
            Button("Keep current", role: .cancel) { }
            Button("Switch to this") {
                store.beginCurrentActivity(activity)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dismiss()
            }
        } message: {
            if let current = store.currentActivity {
                Text("You're already doing “\(current.title)”. Switching won't mark it done.")
            }
        }
        .alert("Remove from Did It?", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                store.removeCompleted(activity)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            }
        } message: {
            Text("This only removes the completion from your history. The idea can be suggested again.")
        }
    }

    private var nearbyKind: DunnoNearbyKind? {
        DunnoNearbyKind.infer(for: activity)
    }

    private var nearbyTaskID: String {
        let status = nearby.authorizationStatus.rawValue
        return "\(activity.id)|\(nearby.isEnabled)|\(status)"
    }

    @ViewBuilder
    private var nearbySection: some View {
        if let kind = nearbyKind {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                        .frame(width: 32, height: 32)
                        .background(Color.dunnoTeal.opacity(0.09), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("near you")
                            .font(Font.dunnoRounded(15, weight: .bold))

                        Text("Optional. Find a real \(kind.label) without changing the activity itself.")
                            .font(Font.dunno(11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !nearby.isEnabled {
                    nearbyPermissionButton(
                        title: "find \(kind.pluralLabel) near me",
                        icon: "location.fill"
                    ) {
                        nearby.setEnabled(true, requestPermission: true)
                    }
                } else if nearby.requiresSettings {
                    Text("Location access is off. Dunno still works normally without it.")
                        .font(Font.dunno(12.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    nearbyPermissionButton(title: "open location settings", icon: "gear") {
                        nearby.openLocationSettings()
                    }
                } else if nearby.authorizationStatus == .notDetermined {
                    nearbyPermissionButton(
                        title: "allow while using dunno",
                        icon: "location.fill"
                    ) {
                        nearby.requestAccessOrRefresh()
                    }
                } else if nearby.isLoading(kind) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("checking for good \(kind.pluralLabel) nearby…")
                            .font(Font.dunno(12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 42)
                } else {
                    let places = nearby.places(for: activity)

                    if places.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Dunno couldn't find an obvious \(kind.label) close by right now.")
                                .font(Font.dunno(12.5, weight: .medium))
                                .foregroundStyle(.secondary)

                            Button {
                                Task { await nearby.loadPlaces(for: activity, force: true) }
                            } label: {
                                Label("try again", systemImage: "arrow.clockwise")
                                    .font(Font.dunno(12.5, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(places.prefix(3).enumerated()), id: \.element.id) { index, place in
                                Button {
                                    nearby.openInMaps(place)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                                            .frame(width: 30, height: 30)
                                            .background(Color.dunnoTeal.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(place.name)
                                                .font(Font.dunno(13.5, weight: .semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)

                                            Text("\(place.distanceLabel) away")
                                                .font(Font.dunno(11, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer(minLength: 8)

                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
                                    }
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(DunnoPressableStyle())
                                .accessibilityHint("Opens this place in Apple Maps.")

                                if index < min(places.count, 3) - 1 {
                                    Divider()
                                        .padding(.leading, 42)
                                }
                            }
                        }
                    }
                }

                Text("Location is checked only while Dunno is open and isn't saved.")
                    .font(Font.dunno(10.5, weight: .medium))
                    .foregroundStyle(DunnoTheme.tertiaryText(for: colorScheme))
            }
            .padding(16)
            .dunnoSolidPanel(cornerRadius: 23, accent: Color.dunnoTeal)
        }
    }

    private func nearbyPermissionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Font.dunno(13.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
        }
        .buttonStyle(DunnoPressableStyle())
        .dunnoGlassPanel(cornerRadius: 17, tint: Color.dunnoTeal.opacity(0.08), interactive: true)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                DunnoArtworkIcon(
                    systemName: activity.category.symbol,
                    size: 52,
                    fallbackColor: accent
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.category.rawValue.lowercased())
                        .font(Font.dunno(10, weight: .bold))
                        .tracking(0.35)
                        .foregroundStyle(textAccent)

                    Text(isCurrent ? "doing now" : isCompleted ? "in did it" : "an idea for you")
                        .font(Font.dunno(12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(activity.title)
                    .font(Font.dunnoRounded(32, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .tracking(-0.45)
                    .fixedSize(horizontal: false, vertical: true)

                Text(activity.hook)
                    .font(Font.dunno(17, weight: .medium))
                    .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var descriptionBlock: some View {
        Text(activity.description)
            .font(Font.dunno(16, weight: .medium))
            .foregroundStyle(DunnoTheme.secondaryText(for: colorScheme))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                infoBox("time", value: activity.durationLabel, icon: "clock")
                infoBox("energy", value: activity.energy.shortLabel, icon: activity.energy.symbol)
            }

            VStack(spacing: 10) {
                infoBox("time", value: activity.durationLabel, icon: "clock")
                infoBox("energy", value: activity.energy.shortLabel, icon: activity.energy.symbol)
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 17) {
            DunnoSectionHeader(title: "try it like this")

            VStack(spacing: 0) {
                ForEach(activity.steps.indices, id: \.self) { index in
                    let step = activity.steps[index]

                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(Font.dunno(11, weight: .bold))
                            .foregroundStyle(textAccent)
                            .frame(width: 27, height: 27)
                            .background(accent.opacity(0.10), in: Circle())

                        Text(step)
                            .font(Font.dunno(15, weight: .medium))
                            .lineSpacing(2)
                            .padding(.top, 3)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13)

                    if index != activity.steps.indices.last {
                        Divider()
                            .opacity(0.55)
                            .padding(.leading, 41)
                    }
                }
            }
        }
        .padding(18)
        .dunnoSolidPanel(cornerRadius: 24, accent: accent)
    }

    private var tags: some View {
        FlowLayout(spacing: 8) {
            ForEach(activity.tags.prefix(5), id: \.self) { tag in
                Text(tag)
                    .font(Font.dunno(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 31)
                    .background(Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.045), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var trailingToolbar: some View {
        if isCurrent {
            EmptyView()
        } else if isCompleted {
            Button(role: .destructive) {
                showingRemoveConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Remove from Did It")
        } else {
            Menu {
                Button {
                    store.toggleSaved(activity)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        store.isSaved(activity) ? "remove from saved" : "save for later",
                        systemImage: store.isSaved(activity) ? "bookmark.slash" : "bookmark"
                    )
                }

                if !store.collections.isEmpty {
                    Menu("add to collection") {
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
                    store.complete(activity)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    Label("already did this", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More options")
        }
    }

    private func sharedStatus(_ mode: DunnoShareMode) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mode == .together ? "person.2.fill" : "paperplane.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))
                .frame(width: 32, height: 32)
                .background(Color.dunnoPurple.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .together ? "someone wants to do this with you" : "someone sent you this")
                    .font(Font.dunnoRounded(14, weight: .bold))
                Text(mode == .together ? "If it sounds good, make it your Doing Now." : "Open it, save it, or make it your next thing.")
                    .font(Font.dunno(12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .dunnoGlassPanel(cornerRadius: 20, tint: Color.dunnoPurple.opacity(0.07))
    }

    private var currentStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                .frame(width: 32, height: 32)
                .background(Color.dunnoTeal.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(startsNow ? "alright. this is the one." : "doing now")
                    .font(Font.dunnoRounded(14, weight: .bold))
                Text(startsNow ? "Dunno will keep it close until you're done." : "Your current pick is waiting in the tab bar.")
                    .font(Font.dunno(12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                store.cancelCurrentActivity()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel doing now")
            .accessibilityHint("Stops this activity without adding it to Did It.")
        }
        .padding(14)
        .dunnoGlassPanel(cornerRadius: 20, tint: Color.dunnoTeal.opacity(0.07))
    }

    private var doingNowControls: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.currentActivityTimerEndAt == nil ? "elapsed" : "timer")
                        .font(Font.dunno(10.5, weight: .semibold))
                        .foregroundStyle(.secondary)

                    if let timerEnd = store.currentActivityTimerEndAt {
                        Text(timerEnd, style: .timer)
                            .font(Font.dunnoRounded(23, weight: .bold))
                            .monospacedDigit()
                    } else if let startedAt = store.currentActivityStartedAt {
                        Text(startedAt, style: .timer)
                            .font(Font.dunnoRounded(23, weight: .bold))
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 10)

                if store.currentActivityTimerEndAt == nil {
                    Button {
                        store.startCurrentActivityTimer(minutes: store.suggestedTimerMinutes(for: activity))
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("start timer", systemImage: "timer")
                            .font(Font.dunno(12.5, weight: .semibold))
                            .padding(.horizontal, 13)
                            .frame(minHeight: 42)
                    }
                    .buttonStyle(DunnoPressableStyle())
                    .dunnoGlassCapsule(interactive: true)
                } else {
                    HStack(spacing: 7) {
                        Button {
                            store.extendCurrentActivityTimer(by: 10)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("+10 min")
                                .font(Font.dunno(12, weight: .semibold))
                                .padding(.horizontal, 11)
                                .frame(minHeight: 42)
                        }
                        .buttonStyle(DunnoPressableStyle())
                        .dunnoGlassCapsule(interactive: true)

                        Button {
                            store.clearCurrentActivityTimer()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "timer.square")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(DunnoPressableStyle())
                        .dunnoGlassCapsule(interactive: true)
                        .accessibilityLabel("Remove timer")
                    }
                }
            }

            Button {
                showingSwitchPicker = true
            } label: {
                Label("switch activity", systemImage: "arrow.triangle.2.circlepath")
                    .font(Font.dunno(12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(DunnoPressableStyle())
            .dunnoGlassCapsule(interactive: true)
            .accessibilityHint("Shows fresh alternatives without marking this activity complete.")

            if let startedAt = store.currentActivityStartedAt {
                Text("started \(startedAt.formatted(date: .omitted, time: .shortened)) · timers are optional and never turn this into a productivity score")
                    .font(Font.dunno(11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .dunnoGlassPanel(cornerRadius: 20, tint: Color.dunnoPurple.opacity(0.045))
    }

    private var privateNoteSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                DunnoSectionHeader(title: "private note")
                Spacer()
                Button {
                    showingNote = true
                } label: {
                    Label(store.note(for: activity).isEmpty ? "add" : "edit", systemImage: "pencil")
                        .font(Font.dunno(11.5, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            if store.note(for: activity).isEmpty {
                Text("Keep a tiny memory from this one. It stays on this device.")
                    .font(Font.dunno(13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text(store.note(for: activity))
                    .font(Font.dunno(14.5, weight: .medium))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .dunnoSolidPanel(cornerRadius: 22, accent: Color.dunnoPurple)
    }

    @ViewBuilder
    private var primaryAction: some View {
        if isCurrent {
            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Label("minimize", systemImage: "chevron.down")
                        .font(Font.dunnoRounded(15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DunnoPressableStyle())
                .dunnoGlassPanel(
                    cornerRadius: 20,
                    tint: Color.dunnoPurple.opacity(0.055),
                    interactive: true
                )
                .accessibilityHint("Closes this screen and keeps the activity in Doing Now.")

                Button {
                    store.complete(activity)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } label: {
                    Label("i'm done", systemImage: "checkmark")
                        .font(Font.dunnoRounded(15, weight: .bold))
                        .foregroundStyle(DunnoTheme.tealText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DunnoPressableStyle())
                .dunnoGlassPanel(
                    cornerRadius: 20,
                    tint: Color.dunnoTeal.opacity(0.10),
                    interactive: true
                )
                .accessibilityHint("Marks this activity complete and adds it to Did It.")
            }
            .padding(.top, 8)
        } else if isCompleted {
            Button {
                requestStart()
            } label: {
                Label("do again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(DunnoPrimaryButtonStyle())
        } else {
            Button {
                requestStart()
            } label: {
                Label("do this", systemImage: "play.fill")
            }
            .buttonStyle(DunnoPrimaryButtonStyle())
        }
    }

    private func requestStart() {
        if let current = store.currentActivity, current.id != activity.id {
            showingReplaceConfirmation = true
            return
        }

        store.beginCurrentActivity(activity)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func infoBox(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.dunno(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(Font.dunno(14, weight: .semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(DunnoTheme.elevatedSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 0.75)
        }
    }
}

private struct DunnoSwitchActivityPicker: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss

    let currentActivity: DunnoActivity
    let onSelect: (DunnoActivity) -> Void

    @State private var options: [DunnoActivity] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                Group {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("finding a few different ideas…")
                                .font(Font.dunno(13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    } else if options.isEmpty {
                        ContentUnavailableView(
                            "no different ideas right now",
                            systemImage: "arrow.triangle.2.circlepath",
                            description: Text("Try changing Right Now or your preferences.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 9) {
                                ForEach(options) { activity in
                                    Button {
                                        onSelect(activity)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: activity.symbol)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(DunnoTheme.categoryAccent(activity.category))
                                                .frame(width: 38, height: 38)
                                                .dunnoGlassCapsule(
                                                    tint: DunnoTheme.categoryAccent(activity.category).opacity(0.08)
                                                )

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(activity.title)
                                                    .font(Font.dunnoRounded(14.5, weight: .semibold))
                                                    .foregroundStyle(.primary)
                                                    .multilineTextAlignment(.leading)
                                                    .lineLimit(2)
                                                Text(activity.durationLabel)
                                                    .font(Font.dunno(11.5, weight: .medium))
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(13)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .dunnoGlassPanel(cornerRadius: 18, interactive: true)
                                    }
                                    .buttonStyle(DunnoPressableStyle())
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("switch activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
        .task {
            // Let the sheet present first. The recommendation engine is much faster after
            // its caching pass, but it still should not compete with the button animation.
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            options = Array(
                store.recommendations(limit: 12)
                    .filter { $0.id != currentActivity.id }
                    .prefix(8)
            )
            isLoading = false
        }
    }
}
