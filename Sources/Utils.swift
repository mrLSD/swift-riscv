import Foundation

/// Combine bytes to x32 number
func combineBytes32(_ x: [UInt8]) -> UInt32 {
    x.enumerated().reduce(0) { acc, element -> UInt32 in
        let (i, n) = element
        return acc | (UInt32(n) << (i * 8))
    }
}

/// Combine bytes to x64 number
func combineBytes64(_ x: [UInt8]) -> UInt64 {
    x.enumerated().reduce(0) { acc, element -> UInt64 in
        let (i, n) = element
        return acc | (UInt64(n) << (i * 8))
    }
}
