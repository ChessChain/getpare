// App/Sources/Views/Categories/CategoryType.swift

import Foundation

enum CategoryType {
    case systemJunk, duplicates, largeFiles, downloads, photos, uninstaller, mailCleanup, developerJunk

    var title: String {
        switch self {
        case .systemJunk:    return "System Junk"
        case .duplicates:    return "Duplicates"
        case .largeFiles:    return "Large & Old Files"
        case .downloads:     return "Downloads"
        case .photos:        return "Photos"
        case .uninstaller:   return "Uninstaller"
        case .mailCleanup:   return "Mail Cleanup"
        case .developerJunk: return "Developer Junk"
        }
    }

    var subtitle: String {
        switch self {
        case .systemJunk:    return "Caches, logs, and language files that macOS will regenerate on demand. Pare excludes protected system paths automatically."
        case .duplicates:    return "Duplicate files found across Downloads, Documents, and Desktop. Pare keeps the most recent or highest-quality copy by default."
        case .largeFiles:    return "Files above your threshold, sortable by size, date, or type. Nothing here is selected by default \u{2014} you decide what to keep."
        case .downloads:     return "Files in your ~/Downloads folder. Most don\u{2019}t survive their first use \u{2014} and many are duplicates of something already saved elsewhere."
        case .photos:        return "Reclaim space in your Photo Library \u{2014} screenshots, RAW originals, accidental bursts, and similar shots."
        case .uninstaller:   return "Remove an app together with its preferences, caches, and support files. Pare also surfaces leftovers from apps you\u{2019}ve already deleted."
        case .mailCleanup:   return "Apple Mail keeps downloaded attachments on disk even after the message is read. These are safe to remove \u{2014} Mail re-downloads them when you open the message again."
        case .developerJunk: return "Xcode derived data, simulators, archives, and runaway node_modules. The biggest single reclaim category for most developers."
        }
    }

    var filters: [String] {
        switch self {
        case .systemJunk:    return ["All", "Caches", "Logs", "Language", "Preferences"]
        case .duplicates:    return ["All", "Photos", "Documents", "Downloads", "Audio"]
        case .largeFiles:    return ["All", "Video", "Audio", "Images", "Archives", "Documents"]
        case .downloads:     return ["All", "Older than 30d", "Installers (DMG/PKG)", "Duplicates", "Images"]
        case .photos:        return ["All", "Screenshots", "RAW", "Similar", "Live Photos"]
        case .uninstaller:   return ["All", "Installed apps", "Leftover data", "Large apps"]
        case .mailCleanup:   return ["All accounts"]
        case .developerJunk: return ["All", "Xcode", "Simulators", "node_modules", "Caches"]
        }
    }

    /// Directories to scan for this category
    var scanPaths: [(label: String, path: String)] {
        switch self {
        case .systemJunk:
            return [
                ("Library/Caches", "Library/Caches"),
                ("Library/Logs", "Library/Logs"),
            ]
        case .duplicates:
            return [("Downloads", "Downloads"), ("Documents", "Documents"), ("Desktop", "Desktop")]
        case .largeFiles:
            return [("Downloads", "Downloads"), ("Documents", "Documents"), ("Movies", "Movies"), ("Music", "Music"), ("Desktop", "Desktop")]
        case .downloads:
            return [("Downloads", "Downloads")]
        case .photos:
            return [("Pictures", "Pictures")]
        case .uninstaller:
            return [("Applications", "/Applications")]
        case .mailCleanup:
            return [("Library/Mail", "Library/Mail")]
        case .developerJunk:
            return [
                ("Library/Developer", "Library/Developer"),
                ("Library/Caches", "Library/Caches"),
            ]
        }
    }
}
