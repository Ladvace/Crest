import Foundation

/// A cookie that keeps a site signed in, decrypted from another browser's
/// profile. It stays in memory until it is written to a Space's own store,
/// and never reaches the core, sync or a log: only its profile and host
/// cross, to route it.
struct BrowserImportedSignIn: Sendable {
    let profileName: String
    let domain: String
    let name: String
    let value: String
    let path: String
    let expires: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    let sameSite: Int32
    /// The cookie's whole row as the other browser kept it, its value still
    /// sealed with that browser's key, for an engine that lays it down again.
    var row: [String: BrowserSQLiteValue] = [:]

    /// The site the cookie belongs with, as routing compares it.
    var host: String {
        (domain.hasPrefix(".") ? String(domain.dropFirst()) : domain).lowercased()
    }

    var routingSource: ImportPasswordSource {
        ImportPasswordSource(profileName: profileName, host: host)
    }

    /// The profile and site together, which cookies of one site share.
    var siteKey: String { "\(profileName)\u{0}\(host)" }

    /// The cookie as WebKit takes it.
    var cookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain, .path: path.isEmpty ? "/" : path, .name: name, .value: value,
        ]
        if isSecure { properties[.secure] = "TRUE" }
        if let expires { properties[.expires] = expires }
        if isHTTPOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
        switch sameSite {
        case 1: properties[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteLax.rawValue
        case 2: properties[.sameSitePolicy] = HTTPCookieStringPolicy.sameSiteStrict.rawValue
        default: break
        }
        return HTTPCookie(properties: properties)
    }

    /// Whether `cookie` is the one a store already keeps under the same name,
    /// domain and path.
    func matches(_ cookie: HTTPCookie) -> Bool {
        cookie.name == name && cookie.domain.caseInsensitiveCompare(domain) == .orderedSame
            && cookie.path == (path.isEmpty ? "/" : path)
    }
}

/// Reads the cookies another Chromium browser keeps beside its saved
/// passwords, each from a private copy, since Chromium holds the store
/// locked while it runs.
enum BrowserCookieImportReader {
    // MARK: - Static Variables

    private static let maximumCookieCount = 50_000

    // MARK: - Actions - Reading

    /// Each site a profile beside `stores` holds an unexpired cookie for,
    /// once per profile. Reads no value. A profile Crest can't read brings
    /// none.
    static func sites(in stores: [ImportPasswordStore]) async -> [ImportPasswordSource] {
        await Task.detached(priority: .utility) {
            var sites: [ImportPasswordSource] = []
            var seen: Set<String> = []
            for profile in profiles(of: stores) {
                guard
                    let hosts = try? BrowserPasswordSQLiteDatabase.reading(
                        copyOf: profile.cookies, { try $0.cookieHosts(now: Date(), limit: maximumCookieCount) })
                else { continue }
                for host in hosts {
                    let site = ImportPasswordSource(
                        profileName: profile.name,
                        host: (host.hasPrefix(".") ? String(host.dropFirst()) : host).lowercased())
                    if seen.insert("\(site.profileName)\u{0}\(site.host)").inserted { sites.append(site) }
                }
            }
            return sites
        }.value
    }

    /// The cookies of every profile beside `stores`, decrypted with the key
    /// `secret` derives, and how the first readable store is laid out. A
    /// cookie that won't decrypt is left out.
    static func read(
        from stores: [ImportPasswordStore], secret: String
    ) async throws -> (signIns: [BrowserImportedSignIn], schema: BrowserCookieStoreSchema?) {
        try await Task.detached(priority: .userInitiated) {
            let key = try ChromiumPasswordCrypto.key(safeStorageSecret: secret)
            var signIns: [BrowserImportedSignIn] = []
            var firstSchema: BrowserCookieStoreSchema?
            for profile in profiles(of: stores) where signIns.count < maximumCookieCount {
                guard
                    let (schema, records) = try? BrowserPasswordSQLiteDatabase.reading(
                        copyOf: profile.cookies,
                        { database in
                            (
                                try database.cookieStoreSchema(),
                                try database.encryptedCookies(now: Date(), limit: maximumCookieCount - signIns.count)
                            )
                        })
                else { continue }
                firstSchema = firstSchema ?? schema
                for record in records {
                    guard let value = value(of: record, version: schema.version, key: key) else { continue }
                    signIns.append(
                        BrowserImportedSignIn(
                            profileName: profile.name, domain: record.hostKey, name: record.name, value: value,
                            path: record.path, expires: record.expires, isSecure: record.isSecure,
                            isHTTPOnly: record.isHTTPOnly, sameSite: record.sameSite, row: record.row))
                }
            }
            return (signIns, firstSchema)
        }.value
    }

    // MARK: - Actions - Profiles

    /// Each profile folder `stores` sit in, once, by the name the browser
    /// keeps it under, with its cookie store, where it keeps one.
    private static func profiles(of stores: [ImportPasswordStore]) -> [(name: String, cookies: URL)] {
        var seen: Set<String> = []
        return stores.compactMap { store in
            let folder = URL(fileURLWithPath: store.path).deletingLastPathComponent()
            guard seen.insert(folder.path).inserted else { return nil }
            let candidates = [
                folder.appending(path: "Network/Cookies"), folder.appending(path: "Cookies"),
            ]
            guard let cookies = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
            else { return nil }
            return (store.id, cookies)
        }
    }

    // MARK: - Actions - Values

    /// The cookie's value: kept plain where Chromium kept it so, or decrypted
    /// and, from version 24, without the host hash Chromium sealed it with.
    private static func value(of record: BrowserEncryptedCookieRecord, version: Int, key: Data) -> String? {
        if !record.plainValue.isEmpty { return record.plainValue }
        guard let encrypted = record.encryptedValue,
            var decrypted = try? ChromiumPasswordCrypto.decrypt(encrypted, key: key)
        else { return nil }
        if version >= BrowserCookieStoreSchema.hostHashVersion {
            let hash = BrowserCookieStoreSchema.hostHash(record.hostKey)
            guard decrypted.count >= hash.count, decrypted.prefix(hash.count) == hash else { return nil }
            decrypted = decrypted.dropFirst(hash.count)
        }
        return String(data: decrypted, encoding: .utf8)
    }
}
