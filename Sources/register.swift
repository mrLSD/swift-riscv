import Foundation

/// Registers file
/// By default initialised with zero
public struct Registers {
    /// Basic registers count
    let REGISTERS_COUNT = 32
    /// Registers array ofr `Value` register type with length `REGISTERS_COUNT`
    var regs: [Value] = []
    /// Registers bit architecture
    public let architecture: ArchBit

    /// Registers bit architecture
    public enum ArchBit {
        case x32
        case x64
    }

    /// Register value
    public enum Value {
        case x32(UInt32)
        case x64(UInt64)
    }

    /// Init register for specific bit architecture
    /// Init registers with zero
    public init(at archBit: ArchBit) {
        // Init registers with Zero value
        let regZeroValue: Value = switch archBit {
        case .x32: .x32(0)
        case .x64: .x64(0)
        }
        // Init all registers
        regs = Array(repeating: regZeroValue, count: REGISTERS_COUNT)
        // Set register architecture
        architecture = archBit
    }

    /// Set register at index with register `Value`
    public mutating func setRegister(at index: Int, with value: Value) {
        // Check is index in register file range
        assert(index < REGISTERS_COUNT, "Index out of bounds")

        // Ensure that Register architecture the same as register Value
        switch (architecture, value) {
        case (.x32, .x32): regs[index] = value
        case (.x64, .x64): regs[index] = value
        default: assertionFailure("setRegister Value type does not match register architecture")
        }
    }

    /// Get register at index
    public func getRegister(at index: Int) -> Value {
        // Check is index in register file range
        assert(index < REGISTERS_COUNT, "Index out of bounds")

        return regs[index]
    }
}

extension Registers: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Registers(\(regs))"
    }
}
