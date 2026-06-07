// Replica of riscv-fs `Arch.fs` (module ISA.RISCV.Arch)

/// Basic Machine Int representation - include x32
public typealias MachineInt = Int64
/// Basic registers: 0-32
public typealias Register = Int32
/// Value of Register
public typealias RegisterVal = MachineInt
public typealias Opcode = MachineInt
public typealias InstrField = Int32

/// Available RISC-V architectures
public enum Architecture: Sendable, Equatable {
    case RV32
    case RV64
    case RV32i
    case RV64i
    case RV32im
    case RV64im
    case RV32ia
    case RV64ia
    case RV32ima
    case RV64ima
    case RV32ic
    case RV64ic
    case RV32imc
    case RV64imc
    case RV32iac
    case RV64iac
    case RV32imac
    case RV64imac
    // Zicsr (CSR access) and the single-precision 'F' extension. 'F' requires
    // Zicsr for FCSR access, so every F-bearing arch also reports hasZicsr.
    // The ifc combos carry C+F together, which enables the FP-compressed
    // Zcf instructions (C.FLW/C.FSW/C.FLWSP/C.FSWSP) on RV32.
    case RV32izicsr
    case RV64izicsr
    case RV32if
    case RV64if
    case RV32ifc
    case RV64ifc

    public static func fromString(_ x: String) -> Architecture? {
        switch x {
        case "rv32i": .RV32i
        case "rv64i": .RV64i
        case "rv32im": .RV32im
        case "rv64im": .RV64im
        case "rv32ia": .RV32ia
        case "rv64ia": .RV64ia
        case "rv32ima": .RV32ima
        case "rv64ima": .RV64ima
        case "rv32ic": .RV32ic
        case "rv64ic": .RV64ic
        case "rv32imc": .RV32imc
        case "rv64imc": .RV64imc
        case "rv32iac": .RV32iac
        case "rv64iac": .RV64iac
        case "rv32imac": .RV32imac
        case "rv64imac": .RV64imac
        case "rv32izicsr": .RV32izicsr
        case "rv64izicsr": .RV64izicsr
        case "rv32if": .RV32if
        case "rv64if": .RV64if
        case "rv32ifc": .RV32ifc
        case "rv64ifc": .RV64ifc
        default: nil
        }
    }

    /// Get architecture bits
    public var archBits: Architecture {
        switch self {
        case .RV32, .RV32i, .RV32im, .RV32ia, .RV32ima,
             .RV32ic, .RV32imc, .RV32iac, .RV32imac,
             .RV32izicsr, .RV32if, .RV32ifc: .RV32
        default: .RV64
        }
    }

    // Standard-extension predicates (used for decode gating in Decoder.swift)
    public var hasM: Bool {
        switch self {
        case .RV32im, .RV32imc, .RV32ima, .RV32imac,
             .RV64im, .RV64imc, .RV64ima, .RV64imac: true
        default: false
        }
    }

    public var hasA: Bool {
        switch self {
        case .RV32ia, .RV32iac, .RV32ima, .RV32imac,
             .RV64ia, .RV64iac, .RV64ima, .RV64imac: true
        default: false
        }
    }

    public var hasC: Bool {
        switch self {
        case .RV32ic, .RV32imc, .RV32iac, .RV32imac,
             .RV64ic, .RV64imc, .RV64iac, .RV64imac,
             .RV32ifc, .RV64ifc: true
        default: false
        }
    }

    public var hasF: Bool {
        switch self {
        case .RV32if, .RV64if, .RV32ifc, .RV64ifc: true
        default: false
        }
    }

    /// Zicsr is implied by F (FCSR is a CSR) and by the explicit izicsr combos.
    public var hasZicsr: Bool {
        switch self {
        case .RV32izicsr, .RV64izicsr, .RV32if, .RV64if, .RV32ifc, .RV64ifc: true
        default: false
        }
    }
}

public enum TrapErrors: Sendable, Equatable {
    case InstructionFetch(MachineInt)
    case InstructionDecode
    case InstructionExecute
    case JumpAddress
    case BreakAddress
    case ECall
    case EBreak
    case MemAddress(MachineInt)
    case StepLimit
    case IllegalCSR // access to an unknown CSR, or a write to a read-only CSR
}
