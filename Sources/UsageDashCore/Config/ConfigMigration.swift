import Foundation

public enum ConfigMigration {
    /// Returns the config URL to load, migrating a legacy `config.json` to
    /// `config.yaml` on first run. The legacy JSON file is preserved so the
    /// user can roll back.
    ///
    /// Rules:
    /// - If `configURL` exists, use it as-is.
    /// - Else if the sibling `.json` exists, load it and write the YAML file.
    /// - Else return `configURL` unchanged (the loader will report not found).
    public static func migrateIfNeeded(
        configURL: URL,
        environment: [String: String]
    ) throws -> URL {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return configURL
        }

        let legacy = configURL.deletingPathExtension().appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: legacy.path) else {
            return configURL
        }

        let loader = ConfigLoader(environment: environment)
        let config = try loader.loadJSON(data: Data(contentsOf: legacy))
        try ConfigWriter.save(config, to: configURL)
        return configURL
    }
}
