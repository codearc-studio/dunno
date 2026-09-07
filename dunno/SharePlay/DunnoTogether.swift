import Combine
import GroupActivities
import SwiftUI
import UIKit

nonisolated struct DunnoTogetherActivity: GroupActivity, Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let candidateIDs: [String]

    init(id: UUID = UUID(), candidateIDs: [String]) {
        self.id = id
        self.candidateIDs = Array(candidateIDs.prefix(80))
    }

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Dunno Together"
        metadata.subtitle = "Find something everybody actually wants to do."
        metadata.type = .generic
        metadata.fallbackURL = URL(string: "https://dunno.codearc.studio/")
        return metadata
    }
}

@MainActor
final class DunnoTogetherCoordinator: ObservableObject {
    nonisolated enum Phase: String, Codable, Sendable {
        case voting
        case matched
        case doing
    }

    nonisolated struct SessionState: Codable, Sendable {
        let round: Int
        let candidateIndex: Int
        let activityID: String?
        let phase: Phase
        let startedAt: Date?
        let finishedParticipantIDs: Set<UUID>
    }

    nonisolated struct VoteMessage: Codable, Sendable {
        let senderID: UUID
        let round: Int
        let accepted: Bool
    }

    nonisolated struct StateMessage: Codable, Sendable {
        let senderID: UUID
        let state: SessionState
    }

    @Published private(set) var session: GroupSession<DunnoTogetherActivity>?
    @Published private(set) var phase: Phase = .voting
    @Published private(set) var currentActivityID: String?
    @Published private(set) var localVote: Bool?
    @Published private(set) var votes: [UUID: Bool] = [:]
    @Published private(set) var startedAt: Date?
    @Published private(set) var finishedParticipantIDs: Set<UUID> = []

    private var messenger: GroupSessionMessenger?
    private var candidateIndex = 0
    private var round = 0
    private var sessionListener: Task<Void, Never>?
    private var messageTasks: [Task<Void, Never>] = []
    private var cancellables: Set<AnyCancellable> = []

    init() {
        sessionListener = Task { [weak self] in
            for await session in DunnoTogetherActivity.sessions() {
                guard !Task.isCancelled else { return }
                self?.configure(session)
            }
        }
    }


    var isActive: Bool { session != nil }

    var participantCount: Int {
        max(session?.activeParticipants.count ?? 0, session == nil ? 0 : 1)
    }

    var acceptedCount: Int {
        votes.values.filter { $0 }.count
    }

    var finishedCount: Int {
        finishedParticipantIDs.count
    }

    var localParticipantID: UUID? {
        session?.localParticipant.id
    }

    var localIsFinished: Bool {
        guard let localParticipantID else { return false }
        return finishedParticipantIDs.contains(localParticipantID)
    }

    func vote(_ accepted: Bool) {
        guard let session else { return }
        let senderID = session.localParticipant.id
        localVote = accepted
        votes[senderID] = accepted
        send(VoteMessage(senderID: senderID, round: round, accepted: accepted))
        evaluateRoundIfLeader()
    }

    func startMatchedActivity() {
        guard phase == .matched else { return }
        let startedAt = Date()
        applyState(
            SessionState(
                round: round,
                candidateIndex: candidateIndex,
                activityID: currentActivityID,
                phase: .doing,
                startedAt: startedAt,
                finishedParticipantIDs: []
            ),
            broadcast: true
        )
    }

    func markLocalFinished() {
        guard phase == .doing, let session else { return }
        var finished = finishedParticipantIDs
        finished.insert(session.localParticipant.id)
        applyState(
            SessionState(
                round: round,
                candidateIndex: candidateIndex,
                activityID: currentActivityID,
                phase: .doing,
                startedAt: startedAt,
                finishedParticipantIDs: finished
            ),
            broadcast: true
        )
    }

    func leave() {
        session?.leave()
        resetSessionState()
    }

    func endForEveryone() {
        session?.end()
        resetSessionState()
    }

    private func configure(_ session: GroupSession<DunnoTogetherActivity>) {
        resetSessionState(leaveExisting: false)
        self.session = session
        candidateIndex = 0
        round = 0
        currentActivityID = session.activity.candidateIDs.first
        phase = .voting
        messenger = GroupSessionMessenger(session: session)

        session.$state
            .sink { [weak self] state in
                guard case .invalidated = state else { return }
                Task { @MainActor in self?.resetSessionState(leaveExisting: false) }
            }
            .store(in: &cancellables)

        session.$activeParticipants
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.evaluateRoundIfLeader()
                    if self.isLeader { self.broadcastCurrentState() }
                }
            }
            .store(in: &cancellables)

        if let messenger {
            messageTasks = [
                Task { [weak self] in
                    for await (message, _) in messenger.messages(of: VoteMessage.self) {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self?.receive(message) }
                    }
                },
                Task { [weak self] in
                    for await (message, _) in messenger.messages(of: StateMessage.self) {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self?.receive(message) }
                    }
                }
            ]
        }

        session.join()
    }

    private var isLeader: Bool {
        guard let session else { return false }
        let participantIDs = session.activeParticipants.map(\.id)
        guard let smallest = participantIDs.min(by: { $0.uuidString < $1.uuidString }) else { return true }
        return session.localParticipant.id == smallest
    }

    private func receive(_ message: VoteMessage) {
        guard message.round == round, phase == .voting else { return }
        votes[message.senderID] = message.accepted
        evaluateRoundIfLeader()
    }

    private func receive(_ message: StateMessage) {
        guard message.senderID != localParticipantID else { return }
        let incoming = message.state
        guard incoming.round >= round else { return }
        applyState(incoming, broadcast: false)
    }

    private func evaluateRoundIfLeader() {
        guard isLeader, phase == .voting, let session else { return }
        let participantIDs = Set(session.activeParticipants.map(\.id))
        guard !participantIDs.isEmpty, participantIDs.allSatisfy({ votes[$0] != nil }) else { return }

        if participantIDs.allSatisfy({ votes[$0] == true }) {
            applyState(
                SessionState(
                    round: round,
                    candidateIndex: candidateIndex,
                    activityID: currentActivityID,
                    phase: .matched,
                    startedAt: nil,
                    finishedParticipantIDs: []
                ),
                broadcast: true
            )
        } else {
            advanceRound()
        }
    }

    private func advanceRound() {
        guard let candidates = session?.activity.candidateIDs, !candidates.isEmpty else { return }
        round += 1
        candidateIndex = (candidateIndex + 1) % candidates.count
        currentActivityID = candidates[candidateIndex]
        phase = .voting
        localVote = nil
        votes = [:]
        startedAt = nil
        finishedParticipantIDs = []
        broadcastCurrentState()
    }

    private func applyState(_ state: SessionState, broadcast: Bool) {
        let previousPhase = phase
        round = state.round
        candidateIndex = state.candidateIndex
        currentActivityID = state.activityID
        phase = state.phase
        startedAt = state.startedAt
        finishedParticipantIDs = state.finishedParticipantIDs

        if state.phase != .voting {
            localVote = nil
            votes = [:]
        } else if previousPhase != .voting {
            localVote = nil
            votes = [:]
        }

        if broadcast { broadcastCurrentState() }

        if state.phase == .doing,
           previousPhase != .doing,
           let activityID = state.activityID,
           let startedAt = state.startedAt {
            NotificationCenter.default.post(
                name: .dunnoTogetherStartedActivity,
                object: nil,
                userInfo: ["activityID": activityID, "startedAt": startedAt]
            )
        }
    }

    private func broadcastCurrentState() {
        guard let session else { return }
        send(
            StateMessage(
                senderID: session.localParticipant.id,
                state: SessionState(
                    round: round,
                    candidateIndex: candidateIndex,
                    activityID: currentActivityID,
                    phase: phase,
                    startedAt: startedAt,
                    finishedParticipantIDs: finishedParticipantIDs
                )
            )
        )
    }

    private func send<Message: Codable & Sendable>(_ message: Message) {
        guard let messenger else { return }
        Task {
            do {
                try await messenger.send(message)
            } catch {
                #if DEBUG
                print("Dunno Together message failed: \(error)")
                #endif
            }
        }
    }

    private func resetSessionState(leaveExisting: Bool = true) {
        if leaveExisting { session?.leave() }
        messageTasks.forEach { $0.cancel() }
        messageTasks = []
        cancellables.removeAll()
        messenger = nil
        session = nil
        phase = .voting
        currentActivityID = nil
        localVote = nil
        votes = [:]
        startedAt = nil
        finishedParticipantIDs = []
        candidateIndex = 0
        round = 0
    }
}

struct DunnoTogetherSharingController: UIViewControllerRepresentable {
    let activity: DunnoTogetherActivity

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            return try GroupActivitySharingController(activity)
        } catch {
            let controller = UIViewController()
            #if DEBUG
            print("Dunno Together sharing controller failed: \(error)")
            #endif
            return controller
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

struct DunnoTogetherView: View {
    @EnvironmentObject private var store: DunnoStore
    @EnvironmentObject private var together: DunnoTogetherCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var activity: DunnoActivity? {
        guard let id = together.currentActivityID else { return nil }
        return store.activity(id: id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        if let activity {
                            activityCard(activity)
                            controls(activity)
                        } else {
                            ContentUnavailableView("No shared idea", systemImage: "person.2.slash")
                        }
                    }
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("leave") {
                        together.leave()
                        dismiss()
                    }
                    .font(Font.dunno(13, weight: .semibold))
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(Color.dunnoPurple)
            Text("\(max(together.participantCount, 1)) people")
                .font(Font.dunno(13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(together.phase == .voting ? "find a yes" : together.phase == .matched ? "you found one" : "doing together")
                .font(Font.dunno(12, weight: .semibold))
                .foregroundStyle(DunnoTheme.purpleText(for: colorScheme))
        }
        .padding(14)
        .dunnoGlassPanel(cornerRadius: 18)
    }

    private func activityCard(_ activity: DunnoActivity) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            DunnoArtworkIcon(
                systemName: activity.symbol,
                size: 58,
                fallbackColor: DunnoTheme.categoryAccent(activity.category)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(activity.title)
                    .font(Font.dunnoRounded(27, weight: .bold))
                    .tracking(-0.25)
                Text(activity.hook)
                    .font(Font.dunno(15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            HStack(spacing: 8) {
                Label(activity.durationLabel, systemImage: "clock")
                Label(activity.category.rawValue.lowercased(), systemImage: activity.category.symbol)
            }
            .font(Font.dunno(11.5, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dunnoSolidPanel(cornerRadius: 28, accent: DunnoTheme.categoryAccent(activity.category))
    }

    @ViewBuilder
    private func controls(_ activity: DunnoActivity) -> some View {
        switch together.phase {
        case .voting:
            VStack(spacing: 11) {
                if let vote = together.localVote {
                    Label(vote ? "you're in" : "you passed", systemImage: vote ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(Font.dunnoRounded(15, weight: .bold))
                        .foregroundStyle(vote ? Color.dunnoTeal : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .dunnoGlassPanel(cornerRadius: 18)

                    Text("waiting for everyone else…")
                        .font(Font.dunno(12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Button { together.vote(false) } label: {
                            Label("nah", systemImage: "hand.thumbsdown.fill")
                                .font(Font.dunnoRounded(16, weight: .bold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 56)
                                .dunnoGlassPanel(cornerRadius: 20, interactive: true)
                        }
                        .buttonStyle(DunnoPressableStyle())

                        Button { together.vote(true) } label: {
                            Label("i'd do this", systemImage: "hand.thumbsup.fill")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 56)
                        }
                        .buttonStyle(DunnoPrimaryButtonStyle())
                    }
                }
            }

        case .matched:
            VStack(spacing: 10) {
                Label("everyone picked this", systemImage: "sparkles")
                    .font(Font.dunnoRounded(17, weight: .bold))
                    .foregroundStyle(Color.dunnoTeal)

                Button {
                    together.startMatchedActivity()
                } label: {
                    Label("do it together", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                }
                .buttonStyle(DunnoPrimaryButtonStyle())
            }

        case .doing:
            VStack(spacing: 12) {
                if let startedAt = together.startedAt {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("doing together")
                                .font(Font.dunno(11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(startedAt, style: .timer)
                                .font(Font.dunnoRounded(22, weight: .bold))
                                .monospacedDigit()
                        }
                        Spacer()
                        Text("\(together.finishedCount)/\(max(together.participantCount, 1)) done")
                            .font(Font.dunno(12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(15)
                    .dunnoGlassPanel(cornerRadius: 18)
                }

                Button {
                    together.markLocalFinished()
                    if !store.isCompleted(activity) { store.complete(activity) }
                } label: {
                    Label(together.localIsFinished ? "you're done" : "i'm done", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                }
                .buttonStyle(DunnoPrimaryButtonStyle())
                .disabled(together.localIsFinished)
            }
        }
    }
}

extension Notification.Name {
    static let dunnoTogetherStartedActivity = Notification.Name("DunnoTogetherStartedActivity")
}
