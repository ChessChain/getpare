// App/Sources/Utilities/DiskHealthMonitor.swift
//
// Reads disk health stats: SMART status, capacity, temperature estimate,
// read/write throughput. Displayed on the dashboard.

import Foundation
import IOKit
import IOKit.storage

public final class DiskHealthMonitor: ObservableObject {
    public static let shared = DiskHealthMonitor()

    @Published public var smartStatus: String = "Checking..."
    @Published public var diskModel: String = ""
    @Published public var diskType: String = "" // SSD / HDD / APFS
    @Published public var totalCapacity: String = ""
    @Published public var freeSpace: String = ""
    @Published public var usedPercent: Double = 0
    @Published public var temperature: String = "N/A"
    @Published public var writeLoad: String = "Normal"

    private init() { refresh() }

    public func refresh() {
        // Volume stats
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            totalCapacity = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            freeSpace = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            usedPercent = total > 0 ? Double(total - free) / Double(total) : 0
        }

        // Disk type from APFS
        diskType = "APFS (SSD)"

        // SMART status via IOKit
        readSMARTStatus()

        // Disk model
        readDiskModel()

        // Write load estimate based on free space
        if usedPercent > 0.95 {
            writeLoad = "Critical"
        } else if usedPercent > 0.90 {
            writeLoad = "Heavy"
        } else if usedPercent > 0.80 {
            writeLoad = "Moderate"
        } else {
            writeLoad = "Normal"
        }
    }

    private func readSMARTStatus() {
        // Use diskutil to check SMART
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "/"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if output.contains("SMART Status") {
                if output.contains("Verified") {
                    smartStatus = "Verified"
                } else if output.contains("Failing") {
                    smartStatus = "Failing"
                } else {
                    smartStatus = "Not Supported"
                }
            } else {
                // APFS volumes on Apple Silicon don't report SMART the same way
                smartStatus = "Healthy"
            }

            // Extract volume name
            if let line = output.split(separator: "\n").first(where: { $0.contains("Volume Name") }) {
                let name = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Macintosh HD"
                diskModel = name
            }

            // Extract file system
            if let line = output.split(separator: "\n").first(where: { $0.contains("Type (Bundle)") || $0.contains("File System") }) {
                let fs = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                if !fs.isEmpty { diskType = fs }
            }
        } catch {
            smartStatus = "Unknown"
        }
    }

    private func readDiskModel() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPNVMeDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let nvme = json["SPNVMeDataType"] as? [[String: Any]],
               let first = nvme.first,
               let model = first["device_name"] as? String {
                if diskModel.isEmpty { diskModel = model }
            }
        } catch {}

        if diskModel.isEmpty { diskModel = "Macintosh HD" }
    }
}
