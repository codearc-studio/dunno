import Foundation

struct DunnoCollection: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var activityIDs: [String]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, activityIDs: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.activityIDs = activityIDs
        self.createdAt = createdAt
    }

    func contains(_ activity: DunnoActivity) -> Bool {
        activityIDs.contains(activity.id)
    }
}
