import Foundation

/// Machine-local values that must never be committed.
///
/// This file ships with a placeholder. Put your real value in, then tell git to
/// stop tracking your edits:
///
///     git update-index --skip-worktree PeekADo/LocalConfig.swift
///
/// To edit it again later:
///
///     git update-index --no-skip-worktree PeekADo/LocalConfig.swift
enum LocalConfig {

    /// The 32-char hex id from your Notion database's URL
    /// (`notion.so/<workspace>/<THIS_PART>?v=…`). Dashes optional.
    static let databaseID = "PASTE_YOUR_DATABASE_ID_HERE"
}
