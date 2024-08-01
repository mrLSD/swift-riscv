import Foundation

/// Registers file
/// By default initialised with zero
struct Registers {
    /// Basic registers count
    let REGISTERS_COUNT = 32
    /// Registers array of  register data with length `REGISTERS_COUNT`
    private var regs: [MachineValue] = []
    /// Registers bit architecture
    let arch: MachineArch

    /// Init register for specific bit architecture
    /// Init registers with zero
    public init(at arch: MachineArch) {
        // Init registers with Zero value
        let regZeroValue: MachineValue = switch arch {
        case .x32: .x32(0)
        case .x64: .x64(0)
        }
        // Init all registers
        self.regs = Array(repeating: regZeroValue, count: REGISTERS_COUNT)
        // Set register architecture
        self.arch = arch
    }

    /// Set register at index with register `Value`
    mutating func setRegister(at index: Int, with value: MachineValue) {
        // Check is index in register file range
        assert(index < REGISTERS_COUNT, "Index out of bounds")

        // Ensure that Register architecture the same as register Value
        switch (arch, value) {
        case (.x32, .x32): regs[index] = value
        case (.x64, .x64): regs[index] = value
        default: assertionFailure("setRegister Value type does not match register architecture")
        }
    }

    /// Get register at index
    public func getRegister(at index: Int) -> MachineValue {
        // Check is index in register file range
        assert(index < REGISTERS_COUNT, "Index out of bounds")

        return regs[index]
    }
}

extension Registers: CustomDebugStringConvertible {
    var debugDescription: String {
        "Registers(\(regs))"
    }
}
