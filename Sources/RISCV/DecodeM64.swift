// Replica of riscv-fs `DecodeM64.fs` (module ISA.RISCV.Decode.M64)

import Foundation

//================================================================
// 'M64'  (Integer Multiplication and Division 'M' Standard Extension)
public enum InstructionM64: Sendable, Equatable {
    case MULW(rd: Register, rs1: Register, rs2: Register)
    case DIVW(rd: Register, rs1: Register, rs2: Register)
    case DIVUW(rd: Register, rs1: Register, rs2: Register)
    case REMW(rd: Register, rs1: Register, rs2: Register)
    case REMUW(rd: Register, rs1: Register, rs2: Register)

    case None // Instruction not found
}

public enum DecodeM64 {
    /// Decode 'M64' instructions
    public static func Decode(_ mstate: borrowing MachineState, _ instr: InstrField) -> InstructionM64 {
        let opcode = instr.bitSlice(6, 0)
        // Register number can be: 0-32
        let rd = instr.bitSlice(11, 7)
        let rs1 = instr.bitSlice(19, 15)
        let rs2 = instr.bitSlice(24, 20)

        let funct3 = instr.bitSlice(14, 12)
        let funct7 = instr.bitSlice(31, 25)

        switch opcode {
        // RV64M Standard Extension (in addition to RV32M)
        case 0b0111011 where mstate.Arch.archBits == .RV64:
            switch funct7 {
            case 0b0000001:
                switch funct3 {
                // Multiplication Operations
                case 0b000: return .MULW(rd: rd, rs1: rs1, rs2: rs2)
                // Division Operations
                case 0b100: return .DIVW(rd: rd, rs1: rs1, rs2: rs2)
                case 0b101: return .DIVUW(rd: rd, rs1: rs1, rs2: rs2)
                case 0b110: return .REMW(rd: rd, rs1: rs1, rs2: rs2)
                case 0b111: return .REMUW(rd: rd, rs1: rs1, rs2: rs2)
                default: return .None
                }
            default: return .None
            }

        default: return .None
        }
    }

    /// Current ISA print log message for current instruction step
    public static func verbosityMessage(_ instr: InstrField, _ decodedInstr: InstructionM64, _ mstate: borrowing MachineState) {
        let fullName = String(describing: decodedInstr)
        let typeName = String(fullName.prefix(while: { $0 != "(" }))
        let instrMsg =
            switch decodedInstr {
            case let .MULW(rd, rs1, rs2), let .DIVW(rd, rs1, rs2), let .DIVUW(rd, rs1, rs2),
                 let .REMW(rd, rs1, rs2), let .REMUW(rd, rs1, rs2):
                String(format: "x%d, x%d, x%d", rd, rs1, rs2)
            case .None:
                "Undef"
            }
        let pc = String(format: "%08llx:", mstate.PC)
        let instr = String(format: "%08x", instr)
        let msg = padRight(typeName, 7) + instrMsg
        Swift.print(padRight(pc, 12) + padRight(instr, 12) + msg)
    }
}
