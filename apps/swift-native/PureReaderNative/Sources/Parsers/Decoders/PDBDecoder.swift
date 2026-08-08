//
//  PDBDecoder.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//

import Foundation

struct PDBRecord {
    let offset: Int
    let length: Int
}

struct PDBHeader {
    let name: String
    let records: [PDBRecord]
}

struct PDBDecoder {
    /// Parse Palm Database (PDB) header structure and record table
    static func parse(_ bytes: Data) -> PDBHeader {
        let nameEnd = bytes.prefix(min(32, bytes.count)).firstIndex(of: 0) ?? min(32, bytes.count)
        let name = String(bytes: bytes[0..<nameEnd], encoding: .ascii) ?? ""

        guard bytes.count >= 78 else {
            return PDBHeader(name: name, records: [])
        }

        let recordCount = (Int(bytes[76]) << 8) | Int(bytes[77])
        var records: [PDBRecord] = []

        for i in 0..<recordCount {
            let base = 78 + i * 8
            guard base + 4 <= bytes.count else { break }

            let offset = (Int(bytes[base]) << 24) | (Int(bytes[base + 1]) << 16) |
                         (Int(bytes[base + 2]) << 8) | Int(bytes[base + 3])

            let nextBase = base + 8
            let nextOffset: Int
            if i + 1 < recordCount, nextBase + 4 <= bytes.count {
                nextOffset = (Int(bytes[nextBase]) << 24) | (Int(bytes[nextBase + 1]) << 16) |
                             (Int(bytes[nextBase + 2]) << 8) | Int(bytes[nextBase + 3])
            } else {
                nextOffset = bytes.count
            }

            records.append(PDBRecord(offset: offset, length: max(0, nextOffset - offset)))
        }

        return PDBHeader(name: name, records: records)
    }
}
