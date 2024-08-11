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

/// Performs sign extension on a given 32-bit integer `x` assuming `n` significant bits.
///
/// This function shifts the given integer `x` to the left to bring the sign bit
/// to the most significant position and then shifts it back to the right to
/// extend the sign across the entire 32-bit range.
///
/// - Parameters:
///   - x: The integer value to be sign-extended. It is assumed to be 32 bits.
///   - n: The number of significant bits in the original integer that `x` is representing.
///
/// - Returns: A 32-bit integer with the sign extended from the `n` significant bits.
///
/// ## Details
///
/// This function is used to handle cases where a smaller bit-width signed
/// integer is stored within a larger integer type, and you need to preserve
/// the sign of the original smaller integer.
func signExtend(_ x: UInt32, _ n: Int) -> UInt32 {
    let signBitMask: UInt32 = 1 << (n - 1)
    if x & signBitMask != 0 {
        let extendMask: UInt32 = ~((1 << n) - 1)
        return x | extendMask
    }
    return x
}
