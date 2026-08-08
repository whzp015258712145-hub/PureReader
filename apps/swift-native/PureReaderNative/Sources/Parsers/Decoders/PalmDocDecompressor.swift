//
//  PalmDocDecompressor.swift
//  PureReader
//
//  Created by OpenSpec on 2026-03-23.
//

import Foundation

struct PalmDocDecompressor {
    /// PalmDOC LZ77 variant decompression algorithm
    ///
    /// Control byte ranges:
    /// - 0x00: Output literal 0x00
    /// - 0x01-0x08: Copy next N bytes literally
    /// - 0x09-0x7F: Output byte as-is
    /// - 0x80-0xBF: LZ77 backward reference (encoded in 2 bytes: distance + length)
    /// - 0xC0-0xFF: Output space (0x20) + byte XOR 0x80
    static func decompress(_ data: Data) -> String {
        var output = [UInt8]()
        output.reserveCapacity(data.count * 3)
        var i = 0

        while i < data.count {
            let c = Int(data[i])
            i += 1

            if c == 0 {
                output.append(0)
            } else if c >= 1 && c <= 8 {
                for _ in 0..<c {
                    if i < data.count {
                        output.append(data[i])
                        i += 1
                    }
                }
            } else if c <= 0x7F {
                output.append(UInt8(c))
            } else if c <= 0xBF {
                guard i < data.count else { break }
                let next = Int(data[i])
                i += 1
                let distance = ((c & 0x3F) << 3) | ((next >> 5) & 0x07)
                let length = (next & 0x1F) + 3

                if distance > 0 {
                    let start = output.count - distance
                    for j in 0..<length {
                        let idx = start + j
                        if idx >= 0, idx < output.count {
                            output.append(output[idx])
                        }
                    }
                }
            } else {
                output.append(0x20)
                output.append(UInt8(c ^ 0x80))
            }
        }

        return String(bytes: output, encoding: .utf8)
            ?? String(bytes: output, encoding: .isoLatin1)
            ?? ""
    }
}
