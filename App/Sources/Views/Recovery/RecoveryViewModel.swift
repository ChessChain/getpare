// App/Sources/Views/Recovery/RecoveryViewModel.swift

import Foundation
import PareKit

public final class RecoveryViewModel: ObservableObject {

    enum RecoveryFilter: String, CaseIterable, Identifiable {
        case all, systemJunk, developer, downloads, mail
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .all:        return "All"
            case .systemJunk: return "System Junk"
            case .developer:  return "Developer"
            case .downloads:  return "Downloads"
            case .mail:       return "Mail"
            }
        }
    }

    @Published var selectedFilter: RecoveryFilter = .all
    private let store = CleanedItemStore.shared

    var filteredItems: [CleanedItemStore.CleanedItem] {
        let items = store.items
        switch selectedFilter {
        case .all:        return items
        case .systemJunk: return items.filter { $0.category == "System Junk" }
        case .developer:  return items.filter { $0.category == "Developer Junk" }
        case .downloads:  return items.filter { $0.category == "Downloads" }
        case .mail:       return items.filter { $0.category == "Mail Cleanup" }
        }
    }

    var totalCount: Int { store.totalCount }
    var binSizeFormatted: String { store.totalSizeLabel }

    public init() {}

    public func restore(id: String) {
        store.restore(id: id)
    }
}
