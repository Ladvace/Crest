import Foundation

/// An engine that keeps its own cookie stores, and can lay imported sign-ins
/// down in a Space's profile before that profile first opens.
@MainActor
protocol BrowserImportedSignInSeeding {
    /// Writes `signIns` into the profile `profileID`, laid out as `schema`
    /// says, when the profile holds no cookies yet. Answers how many it
    /// wrote, none when the profile already keeps cookies.
    func seed(_ signIns: [BrowserImportedSignIn], schema: BrowserCookieStoreSchema, intoProfile profileID: UUID) -> Int
}
