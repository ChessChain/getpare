// PareKit/IPC/XPCCoder.swift
//
// JSON-based encoding/decoding for Codable types crossing the XPC
// boundary. NSXPCConnection requires ObjC-compatible types in the
// protocol methods; we serialize custom Swift structs to Data (NSData)
// and decode on the other side.

import Foundation

public enum XPCCoder {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
