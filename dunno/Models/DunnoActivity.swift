import Foundation
import SwiftUI

enum DunnoCategory: String, CaseIterable, Codable, Identifiable {
    case create = "Create"
    case tech = "Tech"
    case explore = "Explore"
    case learn = "Learn"
    case relax = "Relax"
    case active = "Active"
    case social = "Social"
    case food = "Food"
    case play = "Play"
    case productive = "Useful"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .create: "paintbrush.fill"
        case .tech: "laptopcomputer"
        case .explore: "safari.fill"
        case .learn: "book.fill"
        case .relax: "moon.stars.fill"
        case .active: "figure.run"
        case .social: "person.2.fill"
        case .food: "fork.knife"
        case .play: "gamecontroller.fill"
        case .productive: "checkmark.circle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .create: [.dunnoPurple, .dunnoBlue]
        case .tech: [.dunnoBlue, Color(hex: 0x78A8FF)]
        case .explore: [.dunnoTeal, .dunnoBlue]
        case .learn: [Color(hex: 0x7B7BFF), .dunnoPurple]
        case .relax: [Color(hex: 0xA88BFF), Color(hex: 0xD79BFF)]
        case .active: [.dunnoTeal, Color(hex: 0x6CE5C7)]
        case .social: [Color(hex: 0xFF9F8D), Color(hex: 0xFFBF8E)]
        case .food: [Color(hex: 0xFFB36B), Color(hex: 0xFF8E8E)]
        case .play: [.dunnoBlue, .dunnoPurple]
        case .productive: [Color(hex: 0x8A95A8), .dunnoBlue]
        }
    }
}

enum DunnoEnergy: String, CaseIterable, Codable, Identifiable {
    case barely = "Barely alive"
    case chill = "Chill"
    case normal = "Normal"
    case energetic = "Let’s do something"

    var id: String { rawValue }

    var level: Int {
        switch self {
        case .barely: 0
        case .chill: 1
        case .normal: 2
        case .energetic: 3
        }
    }

    var shortLabel: String {
        switch self {
        case .barely: "Very low"
        case .chill: "Low"
        case .normal: "Medium"
        case .energetic: "High"
        }
    }

    var symbol: String {
        switch self {
        case .barely: "battery.25percent"
        case .chill: "moon.stars.fill"
        case .normal: "bolt.fill"
        case .energetic: "flame.fill"
        }
    }
}

enum DunnoContext: String, CaseIterable, Codable, Identifiable {
    case anywhere = "Anywhere"
    case home = "At home"
    case computer = "At a computer"
    case phone = "On my phone"
    case outside = "Outside"
    case out = "Out somewhere"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .anywhere: "circle.grid.2x2.fill"
        case .home: "house.fill"
        case .computer: "desktopcomputer"
        case .phone: "iphone"
        case .outside: "sun.max.fill"
        case .out: "mappin.and.ellipse"
        }
    }
}

enum DunnoSocial: String, CaseIterable, Codable, Identifiable {
    case any = "Anyone"
    case solo = "By myself"
    case friend = "With a friend"
    case partner = "With my partner"
    case family = "With family"
    case group = "With a group"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .any: "person.crop.circle.badge.questionmark"
        case .solo: "person.fill"
        case .friend: "person.2.fill"
        case .partner: "heart.fill"
        case .family: "figure.2.and.child.holdinghands"
        case .group: "person.3.fill"
        }
    }
}

struct DunnoActivity: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let hook: String
    let description: String
    let category: DunnoCategory
    let symbol: String
    let minMinutes: Int
    let maxMinutes: Int
    let energy: DunnoEnergy
    let contexts: [DunnoContext]
    let social: [DunnoSocial]
    let tags: [String]
    let goals: [String]
    let steps: [String]

    var durationLabel: String {
        if minMinutes == maxMinutes { return Self.formatDuration(minMinutes) }

        if minMinutes < 60 && maxMinutes < 60 {
            return "\(minMinutes)–\(maxMinutes) min"
        }

        return "\(Self.formatDuration(minMinutes))–\(Self.formatDuration(maxMinutes))"
    }

    private static func formatDuration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }

        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours) hr" }
        return "\(hours) hr \(remainder) min"
    }
}

struct DunnoFilters: Equatable {
    var maxMinutes: Int?
    var energy: DunnoEnergy?
    var context: DunnoContext?
    var social: DunnoSocial?

    var isActive: Bool {
        maxMinutes != nil || energy != nil || context != nil || social != nil
    }
}
