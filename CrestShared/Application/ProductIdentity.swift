enum ProductIdentity {
    static let name = "CrestArk"
    static let bundleIdentifier = "com.ladvace.crestark"
    static let serviceNamespace = bundleIdentifier
    /// The folder the browser's data lives in, which keeps the name it had
    /// before CrestArk: the Chromium engine finds its profiles there.
    static let storageDirectoryName = "Crest"
    /// Whether the app checks a release feed for updates. CrestArk publishes
    /// none yet, and Crest's own feed would offer Crest's builds in its place.
    static let checksForUpdates = false
}
