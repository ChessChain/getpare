// Helper/EntryPoint/ParePrivilegedHelper.swift
//
// Thin entry point for the privileged helper. All logic lives in HelperLib
// so it can be @testable-imported by HelperTests.

import Foundation
import PareKit
import HelperLib

@main
struct ParePrivilegedHelper {
    static func main() {
        let log = PareLogger(.helper, category: "main")
        log.info("ParePrivilegedHelper starting (protocol v\(PareIPC.protocolVersion))")

        let listener = NSXPCListener(machServiceName: PareIPC.helperServiceName)
        let delegate = XPCService()
        listener.delegate = delegate
        listener.resume()

        log.info("Listening on mach service \(PareIPC.helperServiceName)")
        RunLoop.main.run()
    }
}
