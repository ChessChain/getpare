// PareKit/Utilities/Logger.swift
//
// Thin wrapper over os.Logger so the helper and app log in a consistent
// format. The helper additionally writes to ~/Library/Logs/Pare/audit.log
// for the operations transparency surface (Settings → Privacy).

import Foundation
import os

public enum LogChannel: String, Sendable {
    case app    = "com.clearpath.pare.app"
    case helper = "com.clearpath.pare.helper"
    case ipc    = "com.clearpath.pare.ipc"
    case audit  = "com.clearpath.pare.audit"
}

public struct PareLogger: Sendable {
    public let logger: Logger
    public let channel: LogChannel

    public init(_ channel: LogChannel, category: String) {
        self.channel = channel
        self.logger = Logger(subsystem: channel.rawValue, category: category)
    }

    public func info(_ msg: String) {
        logger.info("\(msg, privacy: .public)")
        if channel == .audit { AuditFileWriter.shared.write(level: "INFO", msg) }
    }

    public func warn(_ msg: String) {
        logger.warning("\(msg, privacy: .public)")
        if channel == .audit { AuditFileWriter.shared.write(level: "WARN", msg) }
    }

    public func error(_ msg: String) {
        logger.error("\(msg, privacy: .public)")
        if channel == .audit { AuditFileWriter.shared.write(level: "ERROR", msg) }
    }

    public func debug(_ msg: String) {
        logger.debug("\(msg, privacy: .public)")
    }
}

/// Appends timestamped lines to ~/Library/Logs/Pare/audit.log.
/// Thread-safe via a serial DispatchQueue.
public final class AuditFileWriter: Sendable {
    public static let shared = AuditFileWriter()

    private let queue = DispatchQueue(label: "com.clearpath.pare.audit-writer")
    private let fileURL: URL
    private nonisolated(unsafe) let dateFormatter: ISO8601DateFormatter

    private init() {
        let logsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Pare", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.fileURL = logsDir.appendingPathComponent("audit.log")
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = fmt
    }

    func write(level: String, _ message: String) {
        // Format on the serial queue to keep dateFormatter access single-threaded.
        queue.async { [fileURL, dateFormatter] in
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(level)] \(message)\n"
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: fileURL, options: .atomic)
                }
            }
        }
    }
}
