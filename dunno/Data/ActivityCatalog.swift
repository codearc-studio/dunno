import Foundation

enum ActivityCatalog {
    static let supportedSchemaVersion = 1

    static let document: Document = loadDocument()
    static let all: [DunnoActivity] = document.activities
    static var catalogVersion: Int { document.catalogVersion }

    struct Document: Decodable {
        let schemaVersion: Int
        let catalogVersion: Int
        let activities: [DunnoActivity]
    }

    enum CatalogError: LocalizedError {
        case resourceMissing
        case unsupportedSchema(found: Int, supported: Int)
        case emptyCatalog

        var errorDescription: String? {
            switch self {
            case .resourceMissing:
                "Activities.json is missing from the app bundle."
            case let .unsupportedSchema(found, supported):
                "Activities.json uses schema version \(found), but this build supports version \(supported)."
            case .emptyCatalog:
                "Activities.json decoded successfully, but contains no activities."
            }
        }
    }

    static func decode(data: Data) throws -> Document {
        let decoder = JSONDecoder()
        let document = try decoder.decode(Document.self, from: data)

        guard document.schemaVersion == supportedSchemaVersion else {
            throw CatalogError.unsupportedSchema(
                found: document.schemaVersion,
                supported: supportedSchemaVersion
            )
        }

        guard !document.activities.isEmpty else {
            throw CatalogError.emptyCatalog
        }

        return document
    }

    private static func loadDocument(bundle: Bundle = .main) -> Document {
        do {
            let url = try resourceURL(in: bundle)
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            return try decode(data: data)
        } catch {
            // A missing or malformed bundled catalog is a packaging error, not a recoverable
            // user state. Failing loudly keeps a broken content build from shipping silently.
            fatalError("Dunno could not load its activity catalog: \(error.localizedDescription)")
        }
    }

    private static func resourceURL(in bundle: Bundle) throws -> URL {
        // File-system-synchronized Xcode groups can either flatten resources into the bundle
        // or preserve a folder. Support both layouts so moving Activities.json inside the
        // project does not make the runtime loader fragile.
        if let url = bundle.url(forResource: "Activities", withExtension: "json") {
            return url
        }

        if let url = bundle.url(
            forResource: "Activities",
            withExtension: "json",
            subdirectory: "Resources"
        ) {
            return url
        }

        if let url = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .first(where: { $0.lastPathComponent == "Activities.json" }) {
            return url
        }

        throw CatalogError.resourceMissing
    }
}
