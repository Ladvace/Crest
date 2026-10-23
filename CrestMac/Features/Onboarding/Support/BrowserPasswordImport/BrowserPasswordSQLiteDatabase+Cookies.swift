import CryptoKit
import Foundation
import SQLite3

/// One value a SQLite row holds, as the store typed it.
enum BrowserSQLiteValue: Sendable, Equatable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

/// A cookie as Chromium keeps it, its value still encrypted where it is,
/// with its whole row, so an engine can lay it down again as it was.
struct BrowserEncryptedCookieRecord: Sendable {
    let row: [String: BrowserSQLiteValue]

    var hostKey: String { text("host_key") ?? "" }
    var name: String { text("name") ?? "" }
    var plainValue: String { text("value") ?? "" }
    var path: String { text("path") ?? "/" }
    var isSecure: Bool { integer("is_secure") != 0 }
    var isHTTPOnly: Bool { integer("is_httponly") != 0 }
    /// Chromium's same-site setting: -1 unspecified, 0 none, 1 lax, 2 strict.
    var sameSite: Int32 { Int32(truncatingIfNeeded: integer("samesite") ?? -1) }

    var encryptedValue: Data? {
        if case .blob(let data) = row["encrypted_value"], !data.isEmpty { return data }
        return nil
    }

    /// When it expires, or nil for one that lasts the browsing session.
    var expires: Date? {
        guard integer("has_expires") != 0, let microseconds = integer("expires_utc") else { return nil }
        return Date(
            timeIntervalSince1970: Double(microseconds) / 1_000_000
                - BrowserPasswordSQLiteDatabase.chromiumEpochOffset)
    }

    private func text(_ column: String) -> String? {
        if case .text(let value) = row[column] { return value }
        return nil
    }

    private func integer(_ column: String) -> Int64? {
        if case .integer(let value) = row[column] { return value }
        return nil
    }
}

/// How a Chromium cookie store is laid out: the statements that make its
/// tables and indexes, and its `meta` entries, its version among them. None
/// of it is anyone's data.
struct BrowserCookieStoreSchema: Sendable {
    /// The version from which Chromium seals each value with a hash of its
    /// host in front.
    static let hostHashVersion = 24

    let statements: [String]
    let meta: [String: String]

    var version: Int { meta["version"].flatMap(Int.init) ?? 0 }

    /// The hash of `hostKey` Chromium puts in front of a sealed value.
    static func hostHash(_ hostKey: String) -> Data {
        Data(SHA256.hash(data: Data(hostKey.utf8)))
    }
}

// MARK: - Cookies

extension BrowserPasswordSQLiteDatabase {
    // MARK: - Static Variables

    /// Seconds between 1601, where Chromium counts from, and 1970.
    static let chromiumEpochOffset: Double = 11_644_473_600

    // MARK: - Actions - Cookies

    /// How the cookie store is laid out.
    func cookieStoreSchema() throws -> BrowserCookieStoreSchema {
        guard let handle else { throw BrowserPasswordImportError.unreadableDatabase }
        var statements: [String] = []
        try rows(
            handle,
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type DESC"
        ) { statement in
            if let sql = string(statement, column: 0) { statements.append(sql) }
        }
        var meta: [String: String] = [:]
        try rows(handle, "SELECT key, value FROM meta") { statement in
            if let key = string(statement, column: 0) { meta[key] = string(statement, column: 1) ?? "" }
        }
        return BrowserCookieStoreSchema(statements: statements, meta: meta)
    }

    /// The hosts that hold a cookie that has not expired by `now`, at most
    /// `limit` of them, without reading any value.
    func cookieHosts(now: Date, limit: Int) throws -> [String] {
        guard limit > 0, let handle else { return [] }
        var hosts: [String] = []
        try unexpiredRows(handle, "SELECT DISTINCT host_key FROM cookies", now: now, limit: limit) { statement in
            if let host = string(statement, column: 0), !host.isEmpty { hosts.append(host) }
        }
        return hosts
    }

    /// The cookies that have not expired by `now`, at most `limit` of them,
    /// each with its whole row.
    func encryptedCookies(now: Date, limit: Int) throws -> [BrowserEncryptedCookieRecord] {
        guard limit > 0, let handle else { return [] }
        var records: [BrowserEncryptedCookieRecord] = []
        try unexpiredRows(handle, "SELECT * FROM cookies", now: now, limit: limit) { statement in
            var row: [String: BrowserSQLiteValue] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                guard let name = sqlite3_column_name(statement, column).map({ String(cString: $0) }) else { continue }
                row[name] = value(statement, column: column)
            }
            let record = BrowserEncryptedCookieRecord(row: row)
            if !record.hostKey.isEmpty { records.append(record) }
        }
        return records
    }

    // MARK: - Actions - Rows

    /// Steps `select` over the cookies that have not expired by `now`, at
    /// most `limit` of them.
    private func unexpiredRows(
        _ handle: OpaquePointer, _ select: String, now: Date, limit: Int, _ each: (OpaquePointer) -> Void
    ) throws {
        let time = Int64((now.timeIntervalSince1970 + Self.chromiumEpochOffset) * 1_000_000)
        try rows(
            handle, select + " WHERE has_expires = 0 OR expires_utc > ? LIMIT ?",
            bind: { statement in
                sqlite3_bind_int64(statement, 1, time)
                sqlite3_bind_int(statement, 2, Int32(min(limit, Int(Int32.max))))
            },
            each: each)
    }

    /// Steps `sql` over the store, handing each row to `each`.
    private func rows(
        _ handle: OpaquePointer, _ sql: String, bind: (OpaquePointer) -> Void = { _ in },
        each: (OpaquePointer) -> Void
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw BrowserPasswordImportError.unreadableDatabase
        }
        defer { sqlite3_finalize(statement) }
        bind(statement)
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return }
            guard result == SQLITE_ROW else { throw BrowserPasswordImportError.unreadableDatabase }
            each(statement)
        }
    }

    private func value(_ statement: OpaquePointer, column: Int32) -> BrowserSQLiteValue {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER: .integer(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT: .real(sqlite3_column_double(statement, column))
        case SQLITE_TEXT: string(statement, column: column).map(BrowserSQLiteValue.text) ?? .null
        case SQLITE_BLOB: .blob(data(statement, column: column) ?? Data())
        default: .null
        }
    }
}
