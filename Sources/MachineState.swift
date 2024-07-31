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
    static func +(lhs: Self, rhs: Self) -> Self {
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
    static func -(lhs: Self, rhs: Self) -> Self {
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
    static func +(lhs: Self, rhs: Int) -> Self {
        switch lhs {
        case let .x32(leftValue):
            .x32(leftValue &+ UInt32(rhs))
        case let .x64(leftValue):
            .x64(leftValue &+ UInt64(rhs))
        }
    }

    /// `Sub` operation with `Int` value  with overflow
    static func -(lhs: Self, rhs: Int) -> Self {
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
        case .x32(let v):
            self = Int(v)
        case .x64(let v):
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
    var pc: UInt64
    /// Machine bus
    var bus: Bus
    /// Machine bit architecture
    var arch: MachineArch

    init(arch: MachineArch, pc: UInt64, rom: Bus) {
        self.regs = Registers(at: arch)
        self.pc = pc
        // TODO: init devices
        self.bus = rom
        self.arch = arch
    }
}
