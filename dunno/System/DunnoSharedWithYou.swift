import Combine
import SharedWithYou
import SwiftUI
import UIKit

@MainActor
final class DunnoSharedWithYouStore: ObservableObject {
    @Published private(set) var items: [DunnoSharedWithYouItem] = []

    private let highlightCenter = SWHighlightCenter()

    func refresh() {
        let activitiesByID = Dictionary(uniqueKeysWithValues: ActivityCatalog.all.map { ($0.id, $0) })

        items = highlightCenter.highlights.compactMap { highlight in
            guard let parsed = DunnoShareLink.parse(highlight.url),
                  let activity = activitiesByID[parsed.activityID] else {
                return nil
            }

            return DunnoSharedWithYouItem(
                highlight: highlight,
                activity: activity,
                mode: parsed.mode
            )
        }
    }
}

@MainActor
struct DunnoSharedWithYouItem: Identifiable {
    let highlight: SWHighlight
    let activity: DunnoActivity
    let mode: DunnoShareMode

    // Shared with You combines sharing activity around the same Universal Link into
    // one highlight, so the URL is a stable identity for the shelf row.
    var id: String { highlight.url.absoluteString }
}

struct DunnoSharedWithYouAttributionView: UIViewRepresentable {
    let highlight: SWHighlight
    var maxWidth: CGFloat = 220

    func makeUIView(context: Context) -> SWAttributionView {
        let view = SWAttributionView()
        configure(view)
        return view
    }

    func updateUIView(_ uiView: SWAttributionView, context: Context) {
        configure(uiView)
    }

    private func configure(_ view: SWAttributionView) {
        view.highlight = highlight
        view.preferredMaxLayoutWidth = maxWidth
        view.horizontalAlignment = .leading
        view.displayContext = .summary
        view.backgroundStyle = .default
        view.menuTitleForHideAction = "Remove from Shared with You"
    }
}
