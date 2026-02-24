import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class AlbumStore {
    private var db: OpaquePointer?

    init() {
        let dbURL = Self.databaseURL()
        Self.ensureDirectory(dbURL.deletingLastPathComponent())

        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            createTables()
        }
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    func fetchFavorites() -> Set<String> {
        guard let db else { return [] }
        let sql = "SELECT media_path FROM favorites;"
        var statement: OpaquePointer?
        var result: Set<String> = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    result.insert(String(cString: cString))
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }

    func setFavorite(path: String, isFavorite: Bool) {
        guard db != nil else { return }
        if isFavorite {
            execute(
                "INSERT OR IGNORE INTO favorites (media_path, added_at) VALUES (?, ?);",
                bind: { stmt in
                    self.bindText(stmt, index: 1, text: path)
                    sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
                }
            )
        } else {
            execute(
                "DELETE FROM favorites WHERE media_path = ?;",
                bind: { stmt in
                    self.bindText(stmt, index: 1, text: path)
                }
            )
        }
    }

    func fetchAlbumNames() -> [String] {
        guard let db else { return [] }
        let sql = "SELECT name FROM albums ORDER BY name COLLATE NOCASE;"
        var statement: OpaquePointer?
        var result: [String] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    result.append(String(cString: cString))
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }

    func createAlbum(name: String) {
        execute(
            "INSERT OR IGNORE INTO albums (name, created_at) VALUES (?, ?);",
            bind: { stmt in
                self.bindText(stmt, index: 1, text: name)
                sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
            }
        )
    }

    func renameAlbum(oldName: String, newName: String) {
        execute(
            "UPDATE albums SET name = ? WHERE name = ?;",
            bind: { stmt in
                self.bindText(stmt, index: 1, text: newName)
                self.bindText(stmt, index: 2, text: oldName)
            }
        )
    }

    func deleteAlbum(name: String) {
        execute(
            "DELETE FROM albums WHERE name = ?;",
            bind: { stmt in
                self.bindText(stmt, index: 1, text: name)
            }
        )
    }

    func addMedia(path: String, toAlbum name: String) {
        guard let albumID = albumID(for: name) else { return }
        execute(
            "INSERT OR IGNORE INTO album_items (album_id, media_path, added_at) VALUES (?, ?, ?);",
            bind: { stmt in
                sqlite3_bind_int64(stmt, 1, albumID)
                self.bindText(stmt, index: 2, text: path)
                sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
            }
        )
    }

    func removeMedia(path: String, fromAlbum name: String) {
        guard let albumID = albumID(for: name) else { return }
        execute(
            "DELETE FROM album_items WHERE album_id = ? AND media_path = ?;",
            bind: { stmt in
                sqlite3_bind_int64(stmt, 1, albumID)
                self.bindText(stmt, index: 2, text: path)
            }
        )
    }

    func mediaPaths(inAlbum name: String) -> Set<String> {
        guard let db, let albumID = albumID(for: name) else { return [] }
        let sql = "SELECT media_path FROM album_items WHERE album_id = ?;"
        var statement: OpaquePointer?
        var result: Set<String> = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, albumID)
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    result.insert(String(cString: cString))
                }
            }
        }
        sqlite3_finalize(statement)
        return result
    }

    func removeMediaEverywhere(path: String) {
        execute(
            "DELETE FROM favorites WHERE media_path = ?;",
            bind: { stmt in
                self.bindText(stmt, index: 1, text: path)
            }
        )
        execute(
            "DELETE FROM album_items WHERE media_path = ?;",
            bind: { stmt in
                self.bindText(stmt, index: 1, text: path)
            }
        )
    }

    func isEmpty() -> Bool {
        guard let db else { return true }
        return tableCount(db: db, table: "favorites") == 0
            && tableCount(db: db, table: "albums") == 0
            && tableCount(db: db, table: "album_items") == 0
    }

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS albums (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                created_at REAL NOT NULL
            );
        """)

        execute("""
            CREATE TABLE IF NOT EXISTS album_items (
                album_id INTEGER NOT NULL,
                media_path TEXT NOT NULL,
                added_at REAL NOT NULL,
                PRIMARY KEY (album_id, media_path),
                FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE
            );
        """)

        execute("""
            CREATE TABLE IF NOT EXISTS favorites (
                media_path TEXT PRIMARY KEY,
                added_at REAL NOT NULL
            );
        """)
    }

    private func albumID(for name: String) -> Int64? {
        guard let db else { return nil }
        let sql = "SELECT id FROM albums WHERE name = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        bindText(statement, index: 1, text: name)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return sqlite3_column_int64(statement, 0)
    }

    private func execute(_ sql: String, bind: ((OpaquePointer?) -> Void)? = nil) {
        guard let db else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return
        }

        bind?(statement)
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }

    private func bindText(_ statement: OpaquePointer?, index: Int32, text: String) {
        sqlite3_bind_text(statement, index, (text as NSString).utf8String, -1, SQLITE_TRANSIENT)
    }

    private func tableCount(db: OpaquePointer, table: String) -> Int {
        let sql = "SELECT COUNT(*) FROM \(table);"
        var statement: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW {
            count = Int(sqlite3_column_int(statement, 0))
        }

        sqlite3_finalize(statement)
        return count
    }

    private static func databaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("LumiNest", isDirectory: true)
            .appendingPathComponent("luminest.sqlite")
    }

    private static func ensureDirectory(_ directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
