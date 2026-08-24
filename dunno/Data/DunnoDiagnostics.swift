import Foundation

@MainActor
enum DunnoDiagnostics {
    struct CatalogReport {
        let errors: [String]
        let warnings: [String]

        var isValid: Bool { errors.isEmpty }

        var summary: String {
            var lines: [String] = []
            if !errors.isEmpty {
                lines.append("Catalog errors (\(errors.count)):")
                lines.append(contentsOf: errors.map { "• \($0)" })
            }
            if !warnings.isEmpty {
                if !lines.isEmpty { lines.append("") }
                lines.append("Catalog warnings (\(warnings.count)):")
                lines.append(contentsOf: warnings.map { "• \($0)" })
            }
            return lines.joined(separator: "\n")
        }
    }

    static func validateCatalog(_ activities: [DunnoActivity]) {
        #if DEBUG
        let report = catalogReport(for: activities)

        if !report.warnings.isEmpty {
            print("⚠️ Dunno content validation\n\(report.warnings.map { "• \($0)" }.joined(separator: "\n"))")
        }

        assert(report.isValid, "Dunno activity catalog is invalid:\n\(report.summary)")
        #endif
    }

    static func catalogReport(for activities: [DunnoActivity]) -> CatalogReport {
        var errors: [String] = []
        var warnings: [String] = []

        guard !activities.isEmpty else {
            return CatalogReport(errors: ["The catalog contains no activities."], warnings: [])
        }

        validateIdentity(activities, errors: &errors)
        validateFields(activities, errors: &errors)
        validateCoverage(activities, errors: &errors, warnings: &warnings)
        validateTaxonomyCoverage(activities, errors: &errors)

        return CatalogReport(errors: errors, warnings: warnings)
    }

    private static func validateIdentity(
        _ activities: [DunnoActivity],
        errors: inout [String]
    ) {
        let ids = activities.map(\.id)
        let normalizedTitles = activities.map { DunnoTaxonomy.normalize($0.title) }

        for duplicate in duplicateValues(ids) {
            errors.append("Duplicate activity id: \(duplicate)")
        }

        for duplicate in duplicateValues(normalizedTitles) {
            errors.append("Duplicate activity title: \(duplicate)")
        }

        for activity in activities where !isKebabCaseID(activity.id) {
            errors.append("Activity id must be lowercase kebab-case: \(activity.id)")
        }
    }

    private static func validateFields(
        _ activities: [DunnoActivity],
        errors: inout [String]
    ) {
        for activity in activities {
            let id = activity.id

            requireText(activity.title, field: "title", id: id, errors: &errors)
            requireText(activity.hook, field: "hook", id: id, errors: &errors)
            requireText(activity.description, field: "description", id: id, errors: &errors)
            requireText(activity.symbol, field: "symbol", id: id, errors: &errors)

            if activity.minMinutes <= 0 {
                errors.append("\(id): minMinutes must be positive.")
            }
            if activity.maxMinutes < activity.minMinutes {
                errors.append("\(id): maxMinutes cannot be less than minMinutes.")
            }
            if activity.maxMinutes > 12 * 60 {
                errors.append("\(id): duration exceeds Dunno's 12-hour content limit.")
            }

            requireNonEmpty(activity.contexts, field: "contexts", id: id, errors: &errors)
            requireNonEmpty(activity.social, field: "social", id: id, errors: &errors)
            requireNonEmpty(activity.tags, field: "tags", id: id, errors: &errors)
            requireNonEmpty(activity.goals, field: "goals", id: id, errors: &errors)
            requireNonEmpty(activity.steps, field: "steps", id: id, errors: &errors)

            validateNoDuplicates(activity.contexts.map(\.rawValue), field: "contexts", id: id, errors: &errors)
            validateNoDuplicates(activity.social.map(\.rawValue), field: "social", id: id, errors: &errors)
            validateNoDuplicates(activity.tags, field: "tags", id: id, errors: &errors)
            validateNoDuplicates(activity.goals, field: "goals", id: id, errors: &errors)

            for tag in activity.tags {
                requireText(tag, field: "tag", id: id, errors: &errors)
            }
            for goal in activity.goals {
                requireText(goal, field: "goal", id: id, errors: &errors)
            }
            for step in activity.steps {
                requireText(step, field: "step", id: id, errors: &errors)
            }
        }
    }

    private static func validateCoverage(
        _ activities: [DunnoActivity],
        errors: inout [String],
        warnings: inout [String]
    ) {
        for category in DunnoCategory.allCases {
            let count = activities.filter { $0.category == category }.count
            if count == 0 {
                errors.append("No activity exists in category \(category.rawValue).")
            } else if count < 10 {
                warnings.append("\(category.rawValue) has only \(count) activities; target at least 10 before release.")
            }
        }

        for energy in DunnoEnergy.allCases {
            let count = activities.filter { $0.energy == energy }.count
            if count == 0 {
                errors.append("No activity covers energy level \(energy.rawValue).")
            } else if count < 10 {
                warnings.append("\(energy.rawValue) has only \(count) activities; broaden this energy level before release.")
            }
        }

        for context in DunnoContext.allCases where context != .anywhere {
            let count = activities.filter {
                $0.contexts.contains(context) || $0.contexts.contains(.anywhere)
            }.count
            if count == 0 {
                errors.append("No activity covers context \(context.rawValue).")
            }
        }

        for social in DunnoSocial.allCases where social != .any {
            let count = activities.filter { $0.social.contains(social) }.count
            if count == 0 {
                errors.append("No activity covers social filter \(social.rawValue).")
            }
        }

        let quick10 = activities.filter { $0.maxMinutes <= 10 }.count
        let quick20 = activities.filter { $0.maxMinutes <= 20 }.count
        let longer = activities.filter { $0.maxMinutes >= 90 }.count

        if quick10 < 10 {
            warnings.append("Only \(quick10) activities fully fit in 10 minutes; target at least 10.")
        }
        if quick20 < 25 {
            warnings.append("Only \(quick20) activities fully fit in 20 minutes; target at least 25.")
        }
        if longer < 15 {
            warnings.append("Only \(longer) activities can fill 90+ minutes; add more longer-form ideas.")
        }
    }

    private static func validateTaxonomyCoverage(
        _ activities: [DunnoActivity],
        errors: inout [String]
    ) {
        let allSignals = activities.map(DunnoTaxonomy.activitySignals)

        for choice in DunnoTaxonomy.roles + DunnoTaxonomy.interests {
            let aliases = DunnoTaxonomy.aliases(for: choice.title)
            let hasMatch = allSignals.contains { !$0.isDisjoint(with: aliases) }
            if !hasMatch {
                errors.append("Onboarding choice has no matching activity signal: \(choice.title)")
            }
        }

        for choice in DunnoTaxonomy.goals {
            let normalized = DunnoTaxonomy.normalize(choice.title)
            let hasMatch = activities.contains { activity in
                activity.goals.contains { DunnoTaxonomy.normalize($0) == normalized }
            }
            if !hasMatch {
                errors.append("Onboarding goal has no matching activity: \(choice.title)")
            }
        }
    }

    private static func requireText(
        _ value: String,
        field: String,
        id: String,
        errors: inout [String]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("\(id): \(field) cannot be empty.")
        }
    }

    private static func requireNonEmpty<T>(
        _ values: [T],
        field: String,
        id: String,
        errors: inout [String]
    ) {
        if values.isEmpty {
            errors.append("\(id): \(field) cannot be empty.")
        }
    }

    private static func validateNoDuplicates(
        _ values: [String],
        field: String,
        id: String,
        errors: inout [String]
    ) {
        let normalized = values.map(DunnoTaxonomy.normalize)
        if Set(normalized).count != normalized.count {
            errors.append("\(id): \(field) contains duplicate values.")
        }
    }

    private static func isKebabCaseID(_ value: String) -> Bool {
        guard !value.isEmpty, value.first != "-", value.last != "-", !value.contains("--") else {
            return false
        }

        return value.allSatisfy { character in
            character == "-" || character.isNumber || (character.isLetter && character.isLowercase)
        }
    }

    private static func duplicateValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for value in values {
            if !seen.insert(value).inserted {
                duplicates.insert(value)
            }
        }

        return duplicates.sorted()
    }
}
