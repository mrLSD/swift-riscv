// Replica of riscv-fs `Bits.fs` (module ISA.RISCV.Utils.Bits)
//
// .NET shift semantics note: in F#/.NET the shift count of `<<<`/`>>>` is implicitly
// masked (`& 63` for Int64, `& 31` for Int32). The helpers below replicate that masking
// so degenerate slices behave bit-for-bit like the reference.

public extension Int64 {
    /// Get Bit slice from range
    /// (@inlinable: the decoders call this ~25x per instruction; it must inline
    /// across the module boundary into the executable's specialized hot loop.)
    @inlinable
    @inline(__always)
    func bitSlice(_ endBit: Int, _ startBit: Int) -> Int64 {
        (self >> Int64(startBit & 63)) & ~(-1 << Int64((endBit - startBit + 1) & 63))
    }

    /// Test if bit set at a specified position
    @inlinable
    @inline(__always)
    func isSet(_ i: Int) -> Bool {
        self & (1 << Int64(i & 63)) != 0
    }

    /* bit coercion methods */

    /// To hexadecimal (two's complement, like .NET `%x`)
    var toHex: String {
        "0x" + String(UInt64(bitPattern: self), radix: 16)
    }

    /// To binary string (two's complement, 64 chars, like .NET `Convert.ToString(x, 2)` padded)
    var toBin: String {
        let bin = String(UInt64(bitPattern: self), radix: 2)
        return String(repeating: "0", count: 64 - bin.count) + bin
    }

    /// To array of positions set to 1
    var toArray: [Int] {
        var array: [Int] = []
        for i in 0 ... 63 where isSet(i) {
            array.append(i)
        }
        return array
    }

    /* bit print methods */

    func print() {
        Swift.print(self, terminator: "")
    }

    /// Helper to show bits
    func display() {
        for i in toArray {
            Swift.print("\(i) ", terminator: "")
        }
    }
}

public extension Int32 {
    /// Get Bit slice from range
    /// (@inlinable: the single hottest helper in the emulator — see bitSlice above.)
    @inlinable
    @inline(__always)
    func bitSlice(_ endBit: Int32, _ startBit: Int32) -> Int32 {
        (self >> (startBit & 31)) & ~(-1 << ((endBit - startBit + 1) & 31))
    }

    /// Sign extend bits for x32
    @inlinable
    @inline(__always)
    func signExtend(_ n: Int32) -> Int32 {
        let bitOffset = (32 - n) & 31
        return (self << bitOffset) >> bitOffset
    }
}

/// Combine little-endian bytes into an Int64
public func combineBytes(_ x: [UInt8]) -> Int64 {
    x.withUnsafeBufferPointer { buf in
        let span = buf.span
        var acc: Int64 = 0
        for i in span.indices {
            acc |= Int64(span[i]) << (i << 3)
        }
        return acc
    }
}

/// Load from Memory 1 byte
public func loadByte(_ mem: MemoryMap, _ addr: Int64) -> Int8? {
    mem.loadBytes(1, addr).map { Int8(truncatingIfNeeded: $0) }
}

/// Load from Memory 2 bytes
public func loadHalfWord(_ mem: MemoryMap, _ addr: Int64) -> Int16? {
    mem.loadBytes(2, addr).map { Int16(truncatingIfNeeded: $0) }
}

/// Load from Memory 4 bytes
public func loadWord(_ mem: MemoryMap, _ addr: Int64) -> Int32? {
    mem.loadBytes(4, addr).map { Int32(truncatingIfNeeded: $0) }
}

/// Load from Memory 8 bytes
public func loadDouble(_ mem: MemoryMap, _ addr: Int64) -> Int64? {
    mem.loadBytes(8, addr)
}

/// Right-pad helper replicating .NET `String.Format` left alignment (`{0,-N}`).
func padRight(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}
