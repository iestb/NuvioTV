import Foundation

struct Addon: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let version: String
    let description: String?
    let logo: String?
    let background: String?
    let baseUrl: String
    let catalogs: [CatalogDescriptor]
    let types: [String]
    let resources: [AddonResource]
    let idPrefixes: [String]
    let behaviorHints: AddonBehaviorHints?

    init(
        id: String,
        name: String,
        displayName: String? = nil,
        version: String,
        description: String? = nil,
        logo: String? = nil,
        background: String? = nil,
        baseUrl: String,
        catalogs: [CatalogDescriptor] = [],
        types: [String] = [],
        resources: [AddonResource] = [],
        idPrefixes: [String] = [],
        behaviorHints: AddonBehaviorHints? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name
        self.version = version
        self.description = description
        self.logo = logo
        self.background = background
        self.baseUrl = baseUrl
        self.catalogs = catalogs
        self.types = types
        self.resources = resources
        self.idPrefixes = idPrefixes
        self.behaviorHints = behaviorHints
    }

    var supportsStreams: Bool {
        resources.contains { $0.name == "stream" }
    }

    var supportsMeta: Bool {
        resources.contains { $0.name == "meta" }
    }

    var supportsCatalog: Bool {
        !catalogs.isEmpty
    }

    func catalogUrl(type: String, id: String, extra: [String: String] = [:]) -> URL? {
        var urlString = "\(baseUrl)/catalog/\(type)/\(id)"
        if !extra.isEmpty {
            let extraStr = extra.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "/\(extraStr)"
        }
        urlString += ".json"
        return URL(string: urlString)
    }

    func metaUrl(type: String, id: String) -> URL? {
        URL(string: "\(baseUrl)/meta/\(type)/\(id).json")
    }

    func streamUrl(type: String, id: String) -> URL? {
        URL(string: "\(baseUrl)/stream/\(type)/\(id).json")
    }
}

struct CatalogDescriptor: Identifiable, Codable, Equatable {
    let id: String
    let type: String
    let name: String
    let extra: [CatalogExtra]
    let extraSupported: [String]
    let extraRequired: [String]

    var contentType: ContentType {
        ContentType(rawValue: type)
    }

    var supportsSearch: Bool {
        extraSupported.contains("search") || extra.contains { $0.name == "search" }
    }

    var supportsGenre: Bool {
        extraSupported.contains("genre") || extra.contains { $0.name == "genre" }
    }

    var genreOptions: [String] {
        extra.first { $0.name == "genre" }?.options ?? []
    }
}

struct CatalogExtra: Codable, Equatable {
    let name: String
    let isRequired: Bool
    let options: [String]?
    let defaultValue: String?

    enum CodingKeys: String, CodingKey {
        case name, isRequired, options, defaultValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isRequired = (try? container.decodeIfPresent(Bool.self, forKey: .isRequired)) ?? false
        options = try? container.decodeIfPresent([String].self, forKey: .options)
        defaultValue = try? container.decodeIfPresent(String.self, forKey: .defaultValue)
    }

    init(name: String, isRequired: Bool = false, options: [String]? = nil, defaultValue: String? = nil) {
        self.name = name
        self.isRequired = isRequired
        self.options = options
        self.defaultValue = defaultValue
    }
}

struct AddonResource: Codable, Equatable {
    let name: String
    let types: [String]
    let idPrefixes: [String]?

    init(from decoder: Decoder) throws {
        // Resources can be either a string or an object
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            name = str
            types = []
            idPrefixes = nil
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            types = (try? container.decodeIfPresent([String].self, forKey: .types)) ?? []
            idPrefixes = try? container.decodeIfPresent([String].self, forKey: .idPrefixes)
        }
    }

    init(name: String, types: [String] = [], idPrefixes: [String]? = nil) {
        self.name = name
        self.types = types
        self.idPrefixes = idPrefixes
    }

    enum CodingKeys: String, CodingKey {
        case name, types, idPrefixes
    }
}

struct AddonBehaviorHints: Codable, Equatable {
    let configurable: Bool?
    let configurationRequired: Bool?
    let newEpisodeNotifications: Bool?
}
