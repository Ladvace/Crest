@MainActor
struct LiveBrowserOnboardingImportCommitter:
    BrowserOnboardingImportCommitting
{
    private let safeStorage: any BrowserSafeStorageSecretProviding
    /// The engine that lays sign-ins down in new Spaces' profiles, where it
    /// keeps its own cookie stores.
    private let signInSeeder: (any BrowserImportedSignInSeeding)?

    init(
        safeStorage: any BrowserSafeStorageSecretProviding =
            LaunchScopedBrowserSafeStorage(),
        signInSeeder: (any BrowserImportedSignInSeeding)? = nil
    ) {
        self.safeStorage = safeStorage
        self.signInSeeder = signInSeeder
    }

    func prepare(
        review: SetupImportReview,
        payload: BrowserDetectedImportPayload?
    ) async throws -> BrowserOnboardingPreparedImport {
        let directoryAccess = BrowserImportAccessStore.resolve(for: review.source)
        defer { directoryAccess?.stopAccessing() }

        // One Keychain prompt unlocks both, and only when the review brings
        // either.
        guard let payload, review.includedPasswordCount > 0 || review.includedSignInSiteCount > 0 else {
            return BrowserOnboardingPreparedImport(passwords: [])
        }
        let secret = try safeStorage.secret(for: review.source)
        let passwords =
            review.includedPasswordCount > 0
            ? try await BrowserPasswordImportReader.read(
                from: payload.passwordStores, application: review.source,
                safeStorage: UnlockedBrowserSafeStorage(secret: secret))
            : []
        let signIns =
            review.includedSignInSiteCount > 0
            ? try await BrowserCookieImportReader.read(from: payload.passwordStores, secret: secret)
            : (signIns: [], schema: nil)
        try Task.checkCancellation()
        return BrowserOnboardingPreparedImport(
            passwords: passwords, signIns: signIns.signIns, signInSchema: signIns.schema)
    }

    func finalize(
        review: SetupImportReview,
        preparedImport: BrowserOnboardingPreparedImport,
        browser: BrowserStore
    ) async throws -> BrowserPasswordImportResult {
        // An engine with its own cookie stores takes the sign-ins before the
        // new Spaces' profiles first open, which importing them begins, and
        // WebKit's stores, which its pages never read, take no copy.
        if let signInSeeder {
            if let schema = preparedImport.signInSchema {
                BrowserSignInImportCommitter.seed(
                    preparedImport.signIns, schema: schema, review: review, browser: browser, seeder: signInSeeder)
            }
            try browser.importReviewedSpaces()
        } else {
            try browser.importReviewedSpaces()
            await BrowserSignInImportCommitter.commit(preparedImport.signIns, browser: browser)
        }
        return await BrowserPasswordImportCommitter.commit(preparedImport.passwords, browser: browser)
    }
}

/// The secret the person already unlocked for this import, handed to each
/// read so the Keychain asks once.
private struct UnlockedBrowserSafeStorage: BrowserSafeStorageSecretProviding {
    let secret: String

    func secret(for application: ImportSource) throws -> String { secret }
}
