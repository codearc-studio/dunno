import SwiftUI

struct FiltersView: View {
    @EnvironmentObject private var store: DunnoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let times: [(String, Int?)] = [
        ("Any", nil),
        ("10 min", 10),
        ("15 min", 15),
        ("30 min", 30),
        ("1 hr", 60),
        ("I've got time", 120)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DunnoBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        contextSection("how much time?", symbol: "clock") {
                            FlowLayout(spacing: 8) {
                                ForEach(times.indices, id: \.self) { index in
                                    let item = times[index]
                                    DunnoPill(title: item.0, systemImage: nil, isSelected: store.filters.maxMinutes == item.1) {
                                        store.filters.maxMinutes = item.1
                                    }
                                }
                            }
                        }

                        contextSection("how are you feeling?", symbol: "bolt") {
                            FlowLayout(spacing: 8) {
                                DunnoPill(title: "Anything", systemImage: nil, isSelected: store.filters.energy == nil) {
                                    store.filters.energy = nil
                                }

                                ForEach(DunnoEnergy.allCases) { energy in
                                    DunnoPill(
                                        title: energy.rawValue,
                                        systemImage: energy.symbol,
                                        isSelected: store.filters.energy == energy
                                    ) {
                                        store.filters.energy = energy
                                    }
                                }
                            }
                        }

                        contextSection("where are you?", symbol: "location") {
                            FlowLayout(spacing: 8) {
                                DunnoPill(title: "Doesn't matter", systemImage: nil, isSelected: store.filters.context == nil) {
                                    store.filters.context = nil
                                }

                                ForEach(DunnoContext.allCases.filter { $0 != .anywhere }) { context in
                                    DunnoPill(
                                        title: context.rawValue,
                                        systemImage: context.symbol,
                                        isSelected: store.filters.context == context
                                    ) {
                                        store.filters.context = context
                                    }
                                }
                            }
                        }

                        contextSection("who's around?", symbol: "person.2") {
                            FlowLayout(spacing: 8) {
                                DunnoPill(title: "Doesn't matter", systemImage: nil, isSelected: store.filters.social == nil) {
                                    store.filters.social = nil
                                }

                                ForEach(DunnoSocial.allCases.filter { $0 != .any }) { social in
                                    DunnoPill(
                                        title: social.rawValue,
                                        systemImage: social.symbol,
                                        isSelected: store.filters.social == social
                                    ) {
                                        store.filters.social = social
                                    }
                                }
                            }
                        }

                        matchSummary

                        if store.filters.isActive {
                            Button {
                                withAnimation(reduceMotion ? nil : DunnoMotion.snappy) {
                                    store.filters = DunnoFilters()
                                }
                            } label: {
                                Label("clear right now", systemImage: "arrow.counterclockwise")
                                    .font(Font.dunno(14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .frame(height: 42)
                                    .dunnoGlassCapsule(interactive: true)
                            }
                            .buttonStyle(DunnoPressableStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 98)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("done") { dismiss() }
                    .buttonStyle(DunnoPrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
        }
    }


    private var matchSummary: some View {
        let count = store.matchingCount()
        return HStack(spacing: 10) {
            Image(systemName: count == 0 ? "exclamationmark.circle" : "checkmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(count == 0 ? Color.dunnoRose : Color.dunnoTeal)

            Text(count == 0 ? "nothing fits every choice yet" : "\(count) ideas fit right now")
                .font(Font.dunno(13.5, weight: .semibold))
                .foregroundStyle(count == 0 ? Color.dunnoRose : .secondary)

            Spacer()
        }
        .padding(.horizontal, 2)
        .accessibilityLabel(count == 0 ? "No ideas match these filters" : "\(count) ideas match these filters")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("right now")
                .font(Font.dunno(10, weight: .bold))
                .tracking(0.35)
                .foregroundStyle(Color.dunnoPurple)

            Text("what's going on?")
                .font(Font.dunnoRounded(30, weight: .bold))
                .tracking(-0.35)

            Text("Only choose what matters in this moment. These choices clear easily and don't rewrite your profile.")
                .font(Font.dunno(14, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func contextSection<Content: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol)
                .font(Font.dunno(16, weight: .semibold))
                .foregroundStyle(.primary)

            GlassEffectContainer(spacing: 8) {
                content()
            }
        }
    }
}
