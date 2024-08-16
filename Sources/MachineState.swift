import Foundation

/// Machine bit architecture
public enum MachineArch {
    case x32
    case x64
}

/// Machine value
public enum MachineValue {
    case x32(UInt32)
    case x64(UInt64)

    init(from value: UInt32) {
        self = .x32(value)
    }

    init(from value: UInt64) {
        self = .x64(value)
    }

    /// `Add` operation with overflow
    static func + (lhs: Self, rhs: Self) -> Self {
        switch (lhs, rhs) {
        case let (.x32(leftValue), .x32(rightValue)):
            .x32(leftValue &+ rightValue)
        case let (.x64(leftValue), .x64(rightValue)):
            .x64(leftValue &+ rightValue)
        default:
            fatalError("failed operate for: \(lhs),\(rhs)")
        }
    }

    /// `Sub` operation with overflow
    static func - (lhs: Self, rhs: Self) -> Self {
        switch (lhs, rhs) {
        case let (.x32(leftValue), .x32(rightValue)):
            .x32(leftValue &- rightValue)
        case let (.x64(leftValue), .x64(rightValue)):
            .x64(leftValue &- rightValue)
        default:
            fatalError("failed operate for: \(lhs),\(rhs)")
        }
    }

    /// `Add` operation with `Int` value  with overflow
    static func + (lhs: Self, rhs: Int) -> Self {
        switch lhs {
        case let .x32(leftValue):
            .x32(leftValue &+ UInt32(rhs))
        case let .x64(leftValue):
            .x64(leftValue &+ UInt64(rhs))
        }
    }

    /// `Sub` operation with `Int` value  with overflow
    static func - (lhs: Self, rhs: Int) -> Self {
        switch lhs {
        case let .x32(leftValue):
            .x32(leftValue &- UInt32(rhs))
        case let .x64(leftValue):
            .x64(leftValue &- UInt64(rhs))
        }
    }
}

/// Implementation `Int` from `MachineValue`
extension Int {
    init(_ value: MachineValue) {
        switch value {
        case let .x32(v):
            self = Int(v)
        case let .x64(v):
            self = Int(v)
        }
    }
}

extension MachineValue: Comparable {
    public static func < (lhs: MachineValue, rhs: MachineValue) -> Bool {
        switch (lhs, rhs) {
        case let (.x32(leftValue), .x32(rightValue)):
            leftValue < rightValue
        case let (.x64(leftValue), .x64(rightValue)):
            leftValue < rightValue
        default:
            fatalError("failed operate for: \(lhs),\(rhs)")
        }
    }

    public static func <= (lhs: MachineValue, rhs: MachineValue) -> Bool {
        switch (lhs, rhs) {
        case let (.x32(leftValue), .x32(rightValue)):
            leftValue <= rightValue
        case let (.x64(leftValue), .x64(rightValue)):
            leftValue <= rightValue
        default:
            fatalError("failed operate for: \(lhs),\(rhs)")
        }
    }

    public static func > (lhs: MachineValue, rhs: MachineValue) -> Bool {
        switch (lhs, rhs) {
        case let (.x32(leftValue), .x32(rightValue)):
            leftValue > rightValue
        case let (.x64(leftValue), .x64(rightValue)):
            leftValue > rightValue
        default:
            fatalError("failed operate for: \(lhs),\(rhs)")
        }
    }

    public static func >= (lhs: MachineValue, rhs: MachineValue) -> Bool {
        switch (lhs, rhs) {
        case let (.x32(leftValue), .x32(rightValue)):
            leftValue >= rightValue
        case let (.x64(leftValue), .x64(rightValue)):
            leftValue >= rightValue
        default:
            fatalError("failed operate for: \(lhs),\(rhs)")
        }
    }
}

/// Machine state is basic entity for machine running
struct MachineState {
    /// Registers
    var regs: Registers
    /// Program counter
    var pc: MachineValue
    /// Machine bus
    var bus: Bus
    /// Machine bit architecture
    var arch: MachineArch

    /// Exception errors
    enum Exception: Error {
        case instructionAddressMisaligned
        case instructionAccessFault(BusDeviceErrors)
        case illegalInstruction(MachineValue)
    }

    /// Init Machine State
    init(arch: MachineArch, pc: MachineValue, bus: Bus) {
        self.regs = Registers(at: arch)
        self.pc = pc
        self.bus = bus
        self.arch = arch
    }

    func getRegister(_ reg: Register) -> MachineValue {
        self.regs.getRegister(at: reg)
    }

    mutating func setRegister(_ reg: Register, _ val: MachineValue) {
        self.regs.setRegister(at: reg, with: val)
    }

    mutating func setRegister(_ reg: Register, _ val: UInt32) {
        let rawValue = switch self.arch {
        case .x32: MachineValue(from: val)
        case .x64: MachineValue(from: UInt64(val))
        }
        self.regs.setRegister(at: reg, with: rawValue)
    }

    mutating func incPC() {
        self.pc = self.pc + 4
    }

    /// Fetch instruction
    func fetch() -> Result<MachineValue, Exception> {
        self.bus.readWord(from: self.pc).mapError { .instructionAccessFault($0) }
    }

    /// Run execution for with Machine State
    mutating func run() -> Result<Void, Exception> {
        while true {
            // Fetch instruction
            let instr: MachineValue
            switch self.fetch() {
            case let .success(instruction): instr = instruction
            case let .failure(err): return .failure(err)
            }

            // Decode instruction set
            guard let instructionSet = Decoder.decode(instr: instr) else {
                return .failure(.illegalInstruction(instr))
            }

            // Execute instraction
            instructionSet.execute(state: &self)
        }
    }
}
