// MARK: - Sajda/CustomTimetableZip.swift
//
// Minimal read-only ZIP reader for one use case: letting the user pick the
// single `.zip` of monthly CSVs (12 files) instead of selecting the 12
// files by hand.
//
// Pure Swift + Foundation, no extra dependency: the central directory is read
// with Data cursors, stored entries are copied out, deflated entries go
// through a self-contained DEFLATE decoder (fixed + dynamic Huffman, stored
// and fixed/dynamic blocks). Anything it cannot parse — encryption, data
// descriptors, multi-disk, exotic compression — is reported as a bad archive
// rather than decoded into garbage.
//
// The ZIP ends up at `CustomTimetableStore.parseAdhanZip`, which returns the
// merged 12-month calendar just like `parseAdhanFiles`.

import Foundation

extension CustomTimetableStore {
    enum ZipError: LocalizedError {
        case notArchive
        case unsupported(String)
        case corrupt

        var errorDescription: String? {
            switch self {
            case .notArchive: return "That is not a ZIP archive."
            case .unsupported(let what): return "Unsupported ZIP: \(what)."
            case .corrupt: return "The ZIP archive is damaged."
            }
        }
    }

    struct ZipEntry {
        var name: String
        var data: Data
    }

    /// Lists entries visible in the central directory.
    static func listZip(data: Data) throws -> [ZipEntry] {
        try ZipReader(data: data).entries()
    }

    /// Reads a `.zip` of monthly adhan CSVs into the merged 12-month calendar.
    static func parseAdhanZip(url: URL) throws -> [[String: [String]]] {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ImportError.emptyFile
        }
        let entries = try listZip(data: data)
        let csvs = entries.filter {
            $0.name.lowercased().hasSuffix(".csv")
                && !$0.name.hasSuffix("/")
                && !$0.name.contains("__MACOSX/")
                && !$0.name.split(separator: "/").contains(where: { $0.hasPrefix("._") })
        }
        guard !csvs.isEmpty else { throw ImportError.noUsableRows }
        var calendar = Array(repeating: [String: [String]](), count: 12)
        var usable = 0
        for entry in csvs.sorted(by: { $0.name < $1.name }) {
            let month = monthFromFilename(URL(fileURLWithPath: entry.name))
            guard let text = String(data: entry.data, encoding: .utf8) else { continue }
            let partial = try parseAdhanCSV(text, month: month)
            for index in 0..<12 where !partial[index].isEmpty {
                calendar[index].merge(partial[index]) { _, new in new }
                usable += partial[index].count
            }
        }
        // Same March-1 spillover cross-check as the loose-CSV path: a
        // non-leap ZIP's 29th February row is March 1 repeated.
        calendar = dropFebruarySpillover(calendar)
        guard usable > 0 else { throw ImportError.noUsableRows }
        return calendar
    }
}

// MARK: - Minimal ZIP reader (central directory + stored/deflated entries)

/// Reads entry names and bytes out of a ZIP archive using only the central
/// directory, with hard size caps so a hostile file cannot inflate memory.
private struct ZipReader {
    private let data: Data

    /// Refuse archives or expanded members past these sizes.
    private static let maxArchiveBytes = 20 * 1024 * 1024
    private static let maxMemberBytes = 10 * 1024 * 1024
    private static let maxEntries = 256

    init(data: Data) throws {
        guard data.count >= 22, data.count <= Self.maxArchiveBytes else {
            throw CustomTimetableStore.ZipError.notArchive
        }
        self.data = data
    }

    /// Reads little-endian, byte-by-byte: ZIP headers live at arbitrary file
    /// offsets, so an aligned `load(fromByteOffset:as:)` would trap on
    /// misaligned access.
    private func u16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { throw CustomTimetableStore.ZipError.corrupt }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func u32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw CustomTimetableStore.ZipError.corrupt }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private func bytes(at offset: Int, count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset + count <= data.count else {
            throw CustomTimetableStore.ZipError.corrupt
        }
        return data.subdata(in: offset..<(offset + count))
    }

    /// Locates the end-of-central-directory record by scanning backwards.
    private func endOfCentralDirectory() throws -> (entries: Int, offset: Int) {
        let lo = max(0, data.count - 22 - 65535)
        var at = data.count - 22
        while at >= lo {
            if try u32(at: at) == 0x06054B50 {
                let count = Int(try u16(at: at + 10))
                let offset = Int(try u32(at: at + 16))
                return (count, offset)
            }
            at -= 1
        }
        throw CustomTimetableStore.ZipError.notArchive
    }

    func entries() throws -> [CustomTimetableStore.ZipEntry] {
        let (recorded, directoryOffset) = try endOfCentralDirectory()
        guard recorded <= Self.maxEntries else { throw CustomTimetableStore.ZipError.unsupported("too many files") }
        guard directoryOffset < data.count else { throw CustomTimetableStore.ZipError.corrupt }

        var offset = directoryOffset
        var out: [CustomTimetableStore.ZipEntry] = []
        for _ in 0..<recorded {
            guard try u32(at: offset) == 0x02014B50 else { throw CustomTimetableStore.ZipError.corrupt }
            let flags = try u16(at: offset + 8)
            let method = try u16(at: offset + 10)
            guard flags & 0x01 == 0 else { throw CustomTimetableStore.ZipError.unsupported("encrypted file") }
            guard flags & 0x08 == 0 else { throw CustomTimetableStore.ZipError.unsupported("data descriptor") }
            let compressedSize = Int(try u32(at: offset + 20))
            let uncompressedSize = Int(try u32(at: offset + 24))
            let nameLength = Int(try u16(at: offset + 28))
            let extraLength = Int(try u16(at: offset + 30))
            let commentLength = Int(try u16(at: offset + 32))
            let headerOffset = Int(try u32(at: offset + 42))
            offset += 46
            let nameData = try bytes(at: offset, count: nameLength)
            offset += nameLength + extraLength + commentLength
            guard let name = String(data: nameData, encoding: .utf8),
                  compressedSize >= 0, uncompressedSize >= 0,
                  uncompressedSize <= Self.maxMemberBytes else {
                throw CustomTimetableStore.ZipError.corrupt
            }
            if name.hasSuffix("/") { continue }
            let payload = try memberBytes(headerOffset: headerOffset, method: method,
                                          nameLength: nameLength,
                                          compressedSize: compressedSize,
                                          uncompressedSize: uncompressedSize)
            out.append(CustomTimetableStore.ZipEntry(name: name, data: payload))
        }
        return out
    }

    /// Reads one member via its local header and decompresses it.
    private func memberBytes(headerOffset: Int, method: UInt16, nameLength: Int,
                             compressedSize: Int, uncompressedSize: Int) throws -> Data {
        guard try u32(at: headerOffset) == 0x04034B50 else { throw CustomTimetableStore.ZipError.corrupt }
        // Local header layout: sig(4) ver(2) flags(2) method(2) time(2) date(2)
        // crc(4) comp(4) uncomp(4) nameLen(2) extraLen(2).
        let flags = try u16(at: headerOffset + 6)
        guard flags & 0x01 == 0, flags & 0x08 == 0 else {
            throw CustomTimetableStore.ZipError.unsupported("unsupported flags")
        }
        let localMethod = try u16(at: headerOffset + 8)
        guard localMethod == method else { throw CustomTimetableStore.ZipError.corrupt }
        let localNameLength = Int(try u16(at: headerOffset + 26))
        let localExtraLength = Int(try u16(at: headerOffset + 28))
        let start = headerOffset + 30 + localNameLength + localExtraLength
        let raw = try bytes(at: start, count: compressedSize)
        switch method {
        case 0:
            guard raw.count == uncompressedSize else { throw CustomTimetableStore.ZipError.corrupt }
            return raw
        case 8:
            return try DeflateDecoder().decode(raw, expectedSize: uncompressedSize)
        default:
            throw CustomTimetableStore.ZipError.unsupported("compression method \(method)")
        }
    }
}

// MARK: - Self-contained DEFLATE decoder (RFC 1951)

///
/// Bounds work output: output is capped at the ZIP's declared size.

private final class DeflateDecoder {
    fileprivate var bytes: [UInt8] = []
    fileprivate var bitPosition = 0
    fileprivate var output: [UInt8] = []
    private var limit = 0

    func decode(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize >= 0, expectedSize <= 10 * 1024 * 1024 else {
            throw CustomTimetableStore.ZipError.corrupt
        }
        bytes = Array(data)
        bitPosition = 0
        output = []
        output.reserveCapacity(min(expectedSize, 1 << 20))
        limit = expectedSize + 16
        var final = false
        while !final {
            final = try bit() == 1
            let lo = try bit(), hi = try bit()
            switch (lo, hi) {
            case (0, 0): try storedBlock()
            case (1, 0): try fixedBlock()
            case (0, 1): try dynamicBlock()
            default: throw CustomTimetableStore.ZipError.corrupt
            }
        }
        guard output.count == expectedSize else { throw CustomTimetableStore.ZipError.corrupt }
        return Data(output)
    }

    fileprivate func push(_ byte: UInt8) throws {
        guard output.count < limit else { throw CustomTimetableStore.ZipError.corrupt }
        output.append(byte)
    }

    fileprivate func bit() throws -> Int {
        guard bitPosition / 8 < bytes.count else { throw CustomTimetableStore.ZipError.corrupt }
        let value = (Int(bytes[bitPosition / 8]) >> (bitPosition % 8)) & 1
        bitPosition += 1
        return value
    }

    fileprivate func bits(_ count: Int) throws -> Int {
        var value = 0
        for i in 0..<count { value |= (try bit()) << i }
        return value
    }

    /// Stored (uncompressed) block: byte-align, then copy LEN bytes.
    private func storedBlock() throws {
        bitPosition = (bitPosition + 7) / 8 * 8
        guard bitPosition / 8 + 4 <= bytes.count else { throw CustomTimetableStore.ZipError.corrupt }
        let at = bitPosition / 8
        let length = Int(bytes[at]) | (Int(bytes[at + 1]) << 8)
        let check = Int(bytes[at + 2]) | (Int(bytes[at + 3]) << 8)
        guard length ^ check == 0xFFFF else { throw CustomTimetableStore.ZipError.corrupt }
        guard at + 4 + length <= bytes.count else { throw CustomTimetableStore.ZipError.corrupt }
        for i in 0..<length { try push(bytes[at + 4 + i]) }
        bitPosition = (at + 4 + length) * 8
    }

    private func fixedBlock() throws {
        try codedBlock(literal: HuffmanTable.fixedLiteral(), distance: HuffmanTable.fixedDistance())
    }

    private func dynamicBlock() throws {
        let literalCount = try bits(5) + 257
        let distanceCount = try bits(5) + 1
        let orderCount = try bits(4) + 4
        guard literalCount <= 286, distanceCount <= 30 else { throw CustomTimetableStore.ZipError.corrupt }
        let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
        var codeLengths = [Int](repeating: 0, count: 19)
        for i in 0..<orderCount { codeLengths[order[i]] = try bits(3) }
        let codeTable = try HuffmanTable(lengths: codeLengths)
        var all = [Int]()
        all.reserveCapacity(literalCount + distanceCount)
        while all.count < literalCount + distanceCount {
            let symbol = try codeTable.decode(self)
            switch symbol {
            case 0...15:
                all.append(symbol)
            case 16:
                guard let last = all.last else { throw CustomTimetableStore.ZipError.corrupt }
                let count = try bits(2) + 3
                guard all.count + count <= literalCount + distanceCount else {
                    throw CustomTimetableStore.ZipError.corrupt
                }
                all += [Int](repeating: last, count: count)
            case 17:
                let count = try bits(3) + 3
                guard all.count + count <= literalCount + distanceCount else {
                    throw CustomTimetableStore.ZipError.corrupt
                }
                all += [Int](repeating: 0, count: count)
            case 18:
                let count = try bits(7) + 11
                guard all.count + count <= literalCount + distanceCount else {
                    throw CustomTimetableStore.ZipError.corrupt
                }
                all += [Int](repeating: 0, count: count)
            default:
                throw CustomTimetableStore.ZipError.corrupt
            }
        }
        let literal = try HuffmanTable(lengths: Array(all.prefix(literalCount)))
        let distance = try HuffmanTable(lengths: Array(all.suffix(distanceCount)))
        try codedBlock(literal: literal, distance: distance)
    }

    private func codedBlock(literal: HuffmanTable, distance: HuffmanTable) throws {
        while true {
            let symbol = try literal.decode(self)
            if symbol == 256 { return }
            if symbol < 256 {
                try push(UInt8(symbol))
            } else {
                let length = try lengthFor(symbol)
                let distanceSymbol = try distance.decode(self)
                let dist = try distanceFor(distanceSymbol)
                guard dist > 0, dist <= output.count else { throw CustomTimetableStore.ZipError.corrupt }
                // Overlapping matches copy byte-by-byte from the growing tail.
                for _ in 0..<length {
                    try push(output[output.count - dist])
                }
            }
        }
    }

    private func lengthFor(_ symbol: Int) throws -> Int {
        let bases = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
                     35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
        let extras = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                      3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
        guard symbol >= 257, symbol <= 285 else { throw CustomTimetableStore.ZipError.corrupt }
        let i = symbol - 257
        return bases[i] + (extras[i] > 0 ? try bits(extras[i]) : 0)
    }

    private func distanceFor(_ symbol: Int) throws -> Int {
        let bases = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
                     257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
                     8193, 12289, 16385, 24577]
        let extras = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
                      7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
        guard symbol >= 0, symbol <= 29 else { throw CustomTimetableStore.ZipError.corrupt }
        return bases[symbol] + (extras[symbol] > 0 ? try bits(extras[symbol]) : 0)
    }
}

// MARK: - Canonical Huffman table (RFC 1951 section 3.2.2)

/// Decodes symbols from length-prefixed canonical codes, MSB-first, with a
/// bounded number of steps so malformed tables terminate.
private struct HuffmanTable {
    private var codes: [Int: (symbol: Int, length: Int)] = [:]
    private var maxLength = 0

    init(lengths: [Int]) throws {
        let maxBits = lengths.max() ?? 0
        // A block whose prelude (or literal/distance set) carries no codes at
        // all is malformed; without this guard `1...0` traps below.
        guard maxBits >= 1, maxBits <= 15 else { throw CustomTimetableStore.ZipError.corrupt }
        var counts = [Int](repeating: 0, count: maxBits + 1)
        for length in lengths where length > 0 { counts[length] += 1 }
        var next = [Int](repeating: 0, count: maxBits + 1)
        var code = 0
        for bits in 1...maxBits {
            code = (code + counts[bits - 1]) << 1
            next[bits] = code
        }
        for (symbol, length) in lengths.enumerated() where length > 0 {
            codes[next[length]] = (symbol, length)
            next[length] += 1
            maxLength = max(maxLength, length)
        }
    }

    static func fixedLiteral() throws -> HuffmanTable {
        var lengths = [Int](repeating: 0, count: 288)
        for i in 0..<144 { lengths[i] = 8 }
        for i in 144..<256 { lengths[i] = 9 }
        for i in 256..<280 { lengths[i] = 7 }
        for i in 280..<288 { lengths[i] = 8 }
        return try HuffmanTable(lengths: lengths)
    }

    static func fixedDistance() throws -> HuffmanTable {
        try HuffmanTable(lengths: [Int](repeating: 5, count: 30))
    }

    func decode(_ reader: DeflateDecoder) throws -> Int {
        var code = 0
        for length in 1...max(maxLength, 1) {
            code = (code << 1) | (try reader.bit())
            if let entry = codes[code], entry.length == length { return entry.symbol }
            guard length < 15 else { throw CustomTimetableStore.ZipError.corrupt }
        }
        throw CustomTimetableStore.ZipError.corrupt
    }
}

