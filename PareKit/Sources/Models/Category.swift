// PareKit/Models/Category.swift
//
// Cleanup categories. Mapped 1:1 to scanners in Helper/Sources/Scanners/
// and to sidebar entries in App/Sources/Views/. New categories must be
// added here first so the UI and helper stay in sync.

import Foundation

public enum Category: String, Codable, CaseIterable, Sendable {
    case systemJunk
    case duplicate
    case largeFile
    case uninstaller
    case mailCache
    case developerJunk
    case downloads
    case photoLibrary
    case startupItem

    public var displayName: String {
        switch self {
        case .systemJunk:     return "System Junk"
        case .duplicate:      return "Duplicates"
        case .largeFile:      return "Large Files"
        case .uninstaller:    return "Uninstaller"
        case .mailCache:      return "Mail Cleanup"
        case .developerJunk:  return "Developer Junk"
        case .downloads:      return "Downloads"
        case .photoLibrary:   return "Photos"
        case .startupItem:    return "Startup Items"
        }
    }
}
