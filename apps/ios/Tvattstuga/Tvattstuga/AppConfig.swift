import Foundation

enum AppConfig {
    private static let runtimeEnvKey = "API_BASE_URL"
    private static let apiBaseURLKey = "APIBaseURL"
    private static let legacyAPIBaseURLKey = "API_BASE_URL"
    private static let overrideDefaultsKey = "tvattstuga.api_base_url.override"

    private enum Source: String {
        case environment = "Run Arguments env API_BASE_URL"
        case infoPlist = "Build configuration (APIBaseURL)"
        case infoPlistLegacy = "Build configuration (legacy API_BASE_URL)"
        case infoPlistNested = "Build configuration (legacy nested API > BASE > URL)"
        case userOverride = "Debug override in Settings"
    }

    private struct Resolution {
        let value: String
        let source: Source
    }

    static var apiBaseURLString: String {
        resolveAPIBaseURL()?.value ?? ""
    }

    static var apiBaseURLSourceDescription: String {
        resolveAPIBaseURL()?.source.rawValue ?? "Not set"
    }

    static var apiBaseURLOverrideString: String {
        normalized(UserDefaults.standard.string(forKey: overrideDefaultsKey)) ?? ""
    }

    static func setAPIBaseURLOverride(_ value: String) {
        let normalizedValue = normalized(value)
        if let normalizedValue {
            UserDefaults.standard.set(normalizedValue, forKey: overrideDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: overrideDefaultsKey)
        }
    }

    static var apiBaseURL: URL? {
        guard !apiBaseURLString.isEmpty else {
            return nil
        }
        return URL(string: apiBaseURLString)
    }

    private static func resolveAPIBaseURL() -> Resolution? {
        if let fromEnvironment = normalized(
            ProcessInfo.processInfo.environment[runtimeEnvKey]
        ) {
            return Resolution(value: fromEnvironment, source: .environment)
        }

        if let fromInfoPlist = normalized(
            Bundle.main.object(forInfoDictionaryKey: apiBaseURLKey) as? String
        ) {
            return Resolution(value: fromInfoPlist, source: .infoPlist)
        }

        if let fromLegacyInfoPlist = normalized(
            Bundle.main.object(forInfoDictionaryKey: legacyAPIBaseURLKey) as? String
        ) {
            return Resolution(value: fromLegacyInfoPlist, source: .infoPlistLegacy)
        }

        // Compatibility for builds that used INFOPLIST_KEY_API_BASE_URL path syntax.
        if let nested = nestedInfoPlistValue(path: ["API", "BASE", "URL"]) {
            return Resolution(value: nested, source: .infoPlistNested)
        }

        if let fromOverride = normalized(
            UserDefaults.standard.string(forKey: overrideDefaultsKey)
        ) {
            return Resolution(value: fromOverride, source: .userOverride)
        }

        return nil
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nestedInfoPlistValue(path: [String]) -> String? {
        guard var current = Bundle.main.infoDictionary else {
            return nil
        }

        for key in path.dropLast() {
            guard let next = current[key] as? [String: Any] else {
                return nil
            }
            current = next
        }

        guard let leaf = path.last else {
            return nil
        }
        return normalized(current[leaf] as? String)
    }
}
