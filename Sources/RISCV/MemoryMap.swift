// Sparse machine memory.
//
// The F# reference stores memory as a persistent `Map<int64, byte>`: every byte is
// individually mapped or unmapped, and reading an unmapped byte yields None (which the
// callers turn into a MemAddress trap). `MemoryMap` replicates exactly those semantics —
// per-byte mapped/unmapped tracking over the full 64-bit address space, value semantics,
// and a mapped-byte `count` — but is backed by fixed-size pages of contiguous storage so
// the hot paths run at memcpy-like speed. All multi-byte access inside a page goes through
// `Span`/`MutableSpan` (safe, bounds-checked views one step above a raw buffer): one
// uniqueness/bounds setup per access instead of per byte.
public struct MemoryMap: Sendable {
    /// Page granularity: 4 KiB.
    @usableFromInline static let pageShift: Int64 = 12
    @usableFromInline static let pageSize: Int = 1 << pageShift

    /// One page: contiguous bytes plus a bitmap marking which bytes are mapped.
    @usableFromInline
    struct Page: Sendable {
        @usableFromInline var bytes: [UInt8]
        /// 1 bit per byte: 64 words x 64 bits = 4096 flags.
        @usableFromInline var mapped: [UInt64]

        @usableFromInline
        init() {
            bytes = [UInt8](repeating: 0, count: MemoryMap.pageSize)
            mapped = [UInt64](repeating: 0, count: MemoryMap.pageSize / 64)
        }

        @usableFromInline
        func isMapped(_ offset: Int) -> Bool {
            mapped[offset >> 6] & (1 << UInt64(offset & 63)) != 0
        }

        /// Read a single mapped byte, or nil when the byte is unmapped.
        @usableFromInline
        func byte(at offset: Int) -> UInt8? {
            isMapped(offset) ? bytes[offset] : nil
        }

        /// Write a single byte; returns true when the byte was not mapped before.
        @usableFromInline
        mutating func setByte(at offset: Int, _ value: UInt8) -> Bool {
            bytes[offset] = value
            let word = offset >> 6
            let bit: UInt64 = 1 << UInt64(offset & 63)
            let added = mapped[word] & bit == 0
            mapped[word] |= bit
            return added
        }

        /// Load `n` little-endian bytes starting at `offset` (the whole run must lie in
        /// this page). Returns nil when any byte of the run is unmapped.
        @usableFromInline
        func load(_ n: Int, at offset: Int) -> Int64? {
            guard isMappedRange(offset, n) else { return nil }
            // A single Span over the page reads the run with one bounds-checked view —
            // no per-byte array uniqueness checks.
            return bytes.withUnsafeBufferPointer { buf in
                let span = buf.span
                var acc: Int64 = 0
                for i in 0 ..< n {
                    acc |= Int64(span[offset + i]) << (i << 3)
                }
                return acc
            }
        }

        /// Store `n` little-endian bytes of `value` at `offset` (run must lie in this
        /// page); returns how many of those bytes were newly mapped.
        @usableFromInline
        mutating func store(_ n: Int, at offset: Int, _ value: Int64) -> Int {
            bytes.withUnsafeMutableBufferPointer { buf in
                var span = buf.mutableSpan
                for i in 0 ..< n {
                    span[offset + i] = UInt8(truncatingIfNeeded: value >> (i << 3))
                }
            }
            return markMapped(offset, n)
        }

        /// Copy a byte run into the page at `offset`; returns how many bytes were newly
        /// mapped. Used by bulk loads (ELF segments).
        @usableFromInline
        mutating func storeRange(at offset: Int, _ source: ArraySlice<UInt8>) -> Int {
            bytes.withUnsafeMutableBufferPointer { buf in
                var span = buf.mutableSpan
                var i = offset
                for b in source {
                    span[i] = b
                    i += 1
                }
            }
            return markMapped(offset, source.count)
        }

        /// True when all `n` (1...8) bytes starting at `offset` are mapped.
        /// Loads are at most 8 bytes wide, so the run touches at most two bitmap words.
        @usableFromInline
        func isMappedRange(_ offset: Int, _ n: Int) -> Bool {
            MemoryMap.isMappedRun(mapped, offset, n)
        }

        /// Mark `n` bytes starting at `offset` mapped; returns how many were new.
        @usableFromInline
        mutating func markMapped(_ offset: Int, _ n: Int) -> Int {
            mapped.withUnsafeMutableBufferPointer { buf in
                var span = buf.mutableSpan
                var added = 0
                var i = offset
                let end = offset + n
                while i < end {
                    let word = i >> 6
                    // Cover the run of bits that fall into this bitmap word.
                    let upTo = min(end, (word + 1) << 6)
                    let lowBit = UInt64(i & 63)
                    let highBit = UInt64((upTo - 1) & 63)
                    let mask = (~UInt64(0) >> (63 - highBit)) & (~UInt64(0) << lowBit)
                    added += (mask & ~span[word]).nonzeroBitCount
                    span[word] |= mask
                    i = upTo
                }
                return added
            }
        }
    }

    @usableFromInline var pages: [Int64: Page]
    /// Number of mapped bytes (the F# `Map.count`).
    public private(set) var count: Int
    /// Mutation tracking for the fetch fast path in `Run.runSteps`: `generation`
    /// increments on every page write and `lastMutatedKey` records the affected
    /// page. The loop-local fetch cache stays valid across a single-step write to
    /// ANOTHER page and drops conservatively otherwise (including any multi-bump
    /// generation jump from cross-page or wrapping stores).
    @usableFromInline var generation: Int
    @usableFromInline var lastMutatedKey: Int64

    public init() {
        pages = [:]
        count = 0
        generation = 0
        lastMutatedKey = .min
    }

    /// The empty memory (the F# `Map.empty`).
    public static var empty: MemoryMap { MemoryMap() }

    @usableFromInline
    static func pageKey(_ addr: Int64) -> Int64 { addr >> pageShift }

    @usableFromInline
    static func pageOffset(_ addr: Int64) -> Int { Int(addr & Int64(pageSize - 1)) }

    /// Read one byte; nil when the address is unmapped.
    public subscript(addr: Int64) -> UInt8? {
        pages[Self.pageKey(addr)]?.byte(at: Self.pageOffset(addr))
    }

    /// Record a mutation of the page holding `key` (fetch-cache invalidation).
    @inline(__always)
    @usableFromInline
    mutating func noteMutation(_ key: Int64) {
        generation &+= 1
        lastMutatedKey = key
    }

    /// Map one byte.
    public mutating func setByte(_ addr: Int64, _ value: UInt8) {
        let key = Self.pageKey(addr)
        noteMutation(key)
        if pages[key, default: Page()].setByte(at: Self.pageOffset(addr), value) {
            count += 1
        }
    }

    /// Load `nBytes` little-endian bytes starting at `addr` (raw addresses, no XLEN
    /// normalization — that is the caller's concern). Returns nil if any byte is unmapped.
    @inline(__always)
    public func loadBytes(_ nBytes: Int, _ addr: Int64) -> Int64? {
        let offset = Self.pageOffset(addr)
        if offset + nBytes <= Self.pageSize {
            // Fast path: the whole run lives in one page.
            return pages[Self.pageKey(addr)]?.load(nBytes, at: offset)
        }
        // The run crosses a page boundary: split it.
        let headLen = Self.pageSize - offset
        guard let head = pages[Self.pageKey(addr)]?.load(headLen, at: offset),
              let tail = loadBytes(nBytes - headLen, addr &+ Int64(headLen))
        else {
            return nil
        }
        return head | (tail << (headLen << 3))
    }

    /// Store `nBytes` little-endian bytes of `value` starting at `addr`.
    public mutating func storeBytes(_ nBytes: Int, _ addr: Int64, _ value: Int64) {
        let offset = Self.pageOffset(addr)
        noteMutation(Self.pageKey(addr))
        if offset + nBytes <= Self.pageSize {
            count += pages[Self.pageKey(addr), default: Page()].store(nBytes, at: offset, value)
            return
        }
        let headLen = Self.pageSize - offset
        count += pages[Self.pageKey(addr), default: Page()].store(headLen, at: offset, value)
        storeBytes(nBytes - headLen, addr &+ Int64(headLen), value >> (headLen << 3))
    }

    /// Bulk-map a byte run starting at `addr` (used by the ELF loader). Splits the run
    /// over pages; each page chunk is written through one MutableSpan.
    public mutating func storeRange(_ addr: Int64, _ data: [UInt8]) {
        var addr = addr
        var index = data.startIndex
        while index < data.endIndex {
            let offset = Self.pageOffset(addr)
            let chunk = min(Self.pageSize - offset, data.endIndex - index)
            noteMutation(Self.pageKey(addr))
            count += pages[Self.pageKey(addr), default: Page()]
                .storeRange(at: offset, data[index ..< index + chunk])
            index += chunk
            addr &+= Int64(chunk)
        }
    }

    /// The backing arrays of a page (fetch fast path). The returned arrays are
    /// COW snapshots: a later write to the page replaces the page's buffers, so
    /// holders must revalidate via `generation` before trusting them.
    @usableFromInline
    func pageArrays(_ key: Int64) -> ([UInt8], [UInt64])? {
        guard let page = pages[key] else { return nil }
        return (page.bytes, page.mapped)
    }

    /// True when all `n` (1...8) bytes starting at `offset` are mapped in `mapped`
    /// (the standalone form of `Page.isMappedRange` for cached page arrays).
    @usableFromInline
    static func isMappedRun(_ mapped: [UInt64], _ offset: Int, _ n: Int) -> Bool {
        mapped.withUnsafeBufferPointer { buf in
            let span = buf.span
            let last = offset + n - 1
            let firstWord = offset >> 6
            let lastWord = last >> 6
            if firstWord == lastWord {
                let mask = (~UInt64(0) >> UInt64(63 - (last & 63))) & (~UInt64(0) << UInt64(offset & 63))
                return span[firstWord] & mask == mask
            }
            let lowMask = ~UInt64(0) << UInt64(offset & 63)
            let highMask = ~UInt64(0) >> UInt64(63 - (last & 63))
            return span[firstWord] & lowMask == lowMask && span[lastWord] & highMask == highMask
        }
    }
}
