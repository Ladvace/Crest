struct LaunchScopedBrowserSafeStorage: BrowserSafeStorageSecretProviding {
    private let safeStorage: (any BrowserSafeStorageSecretProviding)?

    init(
        launchEnvironment: BrowserLaunchEnvironment = .current,
        systemStorage: () -> any BrowserSafeStorageSecretProviding = {
            SecurityBrowserSafeStorage()
        }
    ) {
        safeStorage = launchEnvironment.opensImportKeychain ? systemStorage() : nil
    }

    func secret(for application: ImportSource) throws -> String {
        guard let safeStorage else {
            throw BrowserPasswordImportError.safeStorageUnavailable
        }
        return try safeStorage.secret(for: application)
    }
}
