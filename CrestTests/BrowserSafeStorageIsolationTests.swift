import XCTest

@testable import Crest

final class BrowserSafeStorageIsolationTests: XCTestCase {
    func testIsolatedAndForcedOnboardingUseUnavailableSafeStorage() {
        for values in [
            ["CREST_ISOLATED_SESSION": "1"],
            ["CREST_SHOW_SETUP": "1"],
        ] {
            let safeStorage = LaunchScopedBrowserSafeStorage(
                launchEnvironment: BrowserLaunchEnvironment(
                    values: values,
                    isXCTestRuntime: false
                ),
                systemStorage: {
                    XCTFail(
                        "Isolated onboarding must not construct the system safe-storage provider."
                    )
                    return TestSafeStorage(secret: "unexpected-secret")
                }
            )

            XCTAssertThrowsError(try safeStorage.secret(for: .chrome)) { error in
                XCTAssertEqual(
                    error as? BrowserPasswordImportError,
                    .safeStorageUnavailable
                )
            }
        }
    }

    func testOrdinaryLaunchForwardsToTheSystemSafeStorageProvider() throws {
        let safeStorage = LaunchScopedBrowserSafeStorage(
            launchEnvironment: BrowserLaunchEnvironment(
                values: [:],
                isXCTestRuntime: false
            ),
            systemStorage: {
                TestSafeStorage(secret: "ordinary-secret")
            }
        )

        XCTAssertEqual(
            try safeStorage.secret(for: .chrome),
            "ordinary-secret"
        )
    }

    /// A development copy may ask to open another browser's Keychain item,
    /// but a test run never does, whatever it asks.
    func testAnIsolatedCopyOpensTheImportKeychainOnlyWhenItAsksOutsideTests() throws {
        let asking = ["CREST_ISOLATED_SESSION": "1", "CREST_ALLOW_IMPORT_KEYCHAIN": "1"]
        let developmentCopy = LaunchScopedBrowserSafeStorage(
            launchEnvironment: BrowserLaunchEnvironment(values: asking, isXCTestRuntime: false),
            systemStorage: { TestSafeStorage(secret: "development-secret") }
        )
        XCTAssertEqual(try developmentCopy.secret(for: .arc), "development-secret")

        let testRun = LaunchScopedBrowserSafeStorage(
            launchEnvironment: BrowserLaunchEnvironment(values: asking, isXCTestRuntime: true),
            systemStorage: {
                XCTFail("A test run must not construct the system safe-storage provider.")
                return TestSafeStorage(secret: "unexpected-secret")
            }
        )
        XCTAssertThrowsError(try testRun.secret(for: .arc)) { error in
            XCTAssertEqual(error as? BrowserPasswordImportError, .safeStorageUnavailable)
        }
    }

    private struct TestSafeStorage: BrowserSafeStorageSecretProviding {
        let secret: String

        func secret(for application: ImportSource) throws -> String {
            secret
        }
    }
}
