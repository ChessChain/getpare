// PareKit/IPC/PareSigning.swift
//
// Single source of truth for code-signing constants used by the helper to
// validate incoming app connections and by the app to register the helper.
// Set `expectedTeamID` to your real Apple Developer Team ID before shipping
// any signed build — the helper refuses every connection while it is the
// placeholder value.

import Foundation

public enum PareSigning {
    /// Your Apple Developer Team ID (10-character alphanumeric, e.g. "ABC123DE45").
    /// Found in the Apple Developer portal under Membership.
    /// MUST be replaced before any signed build is shipped.
    public static let expectedTeamID = "TODO_SET_TEAM_ID"

    /// True once `expectedTeamID` has been set to a plausible value.
    public static var isConfigured: Bool {
        expectedTeamID != "TODO_SET_TEAM_ID" && expectedTeamID.count == 10
    }

    /// Code-signing requirement string evaluated by `SecCodeCheckValidity`.
    /// Matches binaries signed by `expectedTeamID` under an Apple cert chain.
    public static var codeSigningRequirement: String {
        "anchor apple generic and certificate leaf[subject.OU] = \"\(expectedTeamID)\""
    }

    /// Plist name used by `SMAppService.daemon(plistName:)`. The matching plist
    /// must live at `Contents/Library/LaunchDaemons/<plistName>` inside the
    /// signed .app bundle.
    public static let helperPlistName = "com.clearpath.pare.helper.plist"
}
