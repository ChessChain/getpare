// PareKit/Models/Risk.swift
//
// Risk classification applied by the scanner to every ScanItem. The
// DeletionEngine in Helper refuses to act on .protected items regardless
// of what the UI requests — this is the last line of defence.

import Foundation

public enum Risk: String, Codable, Sendable {
    /// Safe to remove. Recommended in default selections.
    case safe

    /// Requires explicit user confirmation. Recent / large / ambiguous.
    case caution

    /// Engine-level deny. Kernel paths, /System, /usr, etc.
    case protected
}
