#if CREST_CHROMIUM_HOST
    import Foundation
    import Security
    import SQLite3

    /// Lays an import's sign-ins down in a new Space's Chromium profile before
    /// Chromium first opens it: a cookie store laid out as the other browser's,
    /// each value sealed again with this app's own Safe Storage key. A profile
    /// that already keeps cookies is left alone, and nothing is written when
    /// the key can't be read. The store is written beside the profile under a
    /// temporary name and moved into place whole.
    @MainActor
    struct ChromiumSignInSeeder: BrowserImportedSignInSeeding {
        // MARK: - Static Variables

        private static let bundlePrefix = "com.pauldavis.crest"

        // MARK: - Actions - Seeding

        func seed(_ signIns: [BrowserImportedSignIn], schema: BrowserCookieStoreSchema, intoProfile profileID: UUID)
            -> Int
        {
            guard !signIns.isEmpty, !schema.statements.isEmpty, let key = Self.key() else { return 0 }
            let profile = Self.userDataDirectory().appending(path: "Crest-\(profileID.uuidString)")
            let store = profile.appending(path: "Cookies")
            // Chromium has kept cookies in either place; a profile with either
            // already has cookies of its own.
            guard
                ![store, profile.appending(path: "Network/Cookies")].contains(where: {
                    FileManager.default.fileExists(atPath: $0.path)
                })
            else { return 0 }
            let staging = profile.appending(path: "Cookies.crest-import")
            do {
                try FileManager.default.createDirectory(
                    at: profile, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try? FileManager.default.removeItem(at: staging)
                let written = try Self.write(signIns, schema: schema, key: key, to: staging)
                try FileManager.default.moveItem(at: staging, to: store)
                return written
            } catch {
                try? FileManager.default.removeItem(at: staging)
                return 0
            }
        }

        // MARK: - Actions - Writing

        /// Writes a cookie store at `url` holding `signIns`, answering how many.
        private static func write(
            _ signIns: [BrowserImportedSignIn], schema: BrowserCookieStoreSchema, key: Data, to url: URL
        ) throws -> Int {
            var handle: OpaquePointer?
            guard
                sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
                let database = handle
            else {
                if let handle { sqlite3_close(handle) }
                throw BrowserPasswordImportError.unreadableDatabase
            }
            defer { sqlite3_close(database) }
            try execute(database, "BEGIN")
            for statement in schema.statements { try execute(database, statement) }
            for (name, value) in schema.meta {
                try insert(database, table: "meta", row: ["key": .text(name), "value": .text(value)])
            }
            var written = 0
            for signIn in signIns where !signIn.row.isEmpty {
                var plain = Data(signIn.value.utf8)
                if schema.version >= BrowserCookieStoreSchema.hostHashVersion {
                    plain = BrowserCookieStoreSchema.hostHash(signIn.domain) + plain
                }
                var row = signIn.row
                row["value"] = .text("")
                row["encrypted_value"] = .blob(try ChromiumPasswordCrypto.encrypt(plain, key: key))
                if (try? insert(database, table: "cookies", row: row)) != nil { written += 1 }
            }
            try execute(database, "COMMIT")
            return written
        }

        private static func execute(_ database: OpaquePointer, _ sql: String) throws {
            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                throw BrowserPasswordImportError.unreadableDatabase
            }
        }

        /// Inserts `row` into `table`, replacing a row of the same cookie.
        private static func insert(_ database: OpaquePointer, table: String, row: [String: BrowserSQLiteValue]) throws {
            let columns = row.keys.sorted()
            let names = columns.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ", ")
            let marks = Array(repeating: "?", count: columns.count).joined(separator: ", ")
            var statement: OpaquePointer?
            guard
                sqlite3_prepare_v2(
                    database, "INSERT OR REPLACE INTO \(table) (\(names)) VALUES (\(marks))", -1, &statement, nil)
                    == SQLITE_OK,
                let statement
            else { throw BrowserPasswordImportError.unreadableDatabase }
            defer { sqlite3_finalize(statement) }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (offset, column) in columns.enumerated() {
                let index = Int32(offset + 1)
                switch row[column] ?? .null {
                case .integer(let value): sqlite3_bind_int64(statement, index, value)
                case .real(let value): sqlite3_bind_double(statement, index, value)
                case .text(let value): sqlite3_bind_text(statement, index, value, -1, transient)
                case .blob(let value):
                    _ = value.withUnsafeBytes { bytes in
                        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), transient)
                    }
                case .null: sqlite3_bind_null(statement, index)
                }
            }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw BrowserPasswordImportError.unreadableDatabase }
        }

        // MARK: - Actions - Locations

        /// Where Chromium keeps this app's profiles: the folder the launch
        /// names, or the installed app's.
        private static func userDataDirectory() -> URL {
            let flag = "--user-data-dir="
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(flag) }) {
                return URL(fileURLWithPath: String(argument.dropFirst(flag.count)), isDirectory: true)
            }
            return FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support/Crest/Chromium", directoryHint: .isDirectory)
        }

        /// This app's Safe Storage key, under the Keychain item the engine
        /// names for this bundle: Crest's own for a `com.pauldavis.crest`
        /// bundle, Chromium's shared item for any other. Nil when the Keychain
        /// doesn't give it.
        private static func key() -> Data? {
            guard let bundle = Bundle.main.bundleIdentifier else { return nil }
            let (service, account): (String, String) =
                if bundle == bundlePrefix || bundle.hasPrefix(bundlePrefix + ".") {
                    (
                        crestService(
                            suffix: bundle == bundlePrefix ? nil : String(bundle.dropFirst(bundlePrefix.count + 1))),
                        bundle
                    )
                } else {
                    ("Chromium Safe Storage", "Chromium")
                }
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
                kSecMatchLimit: kSecMatchLimitOne, kSecReturnData: true,
            ]
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                let data = result as? Data, let secret = String(data: data, encoding: .utf8), !secret.isEmpty
            else { return nil }
            return try? ChromiumPasswordCrypto.key(safeStorageSecret: secret)
        }

        /// The Keychain item the engine names for a Crest bundle, by what
        /// follows `com.pauldavis.crest.` in its identity.
        private static func crestService(suffix: String?) -> String {
            switch suffix {
            case nil: "Crest Safe Storage"
            case "control-plane.chromium": "Crest Review Safe Storage"
            case "chromium-baseline": "Crest Chromium Baseline Safe Storage"
            case let suffix?: "Crest \(suffix) Safe Storage"
            }
        }
    }
#endif
