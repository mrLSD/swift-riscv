// Replica of riscv-fs `DecodeA64.fs` (module ISA.RISCV.Decode.A64)

import Foundation

//================================================================
// 'A64'  (Atomic Memory Operations 'A' Standard Extension)
public enum InstructionA64: Sendable, Equatable {
    case LR_D(rd: Register, rs1: Register, aq: InstrField, rl: InstrField)
    case SC_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)

    case AMOSWAP_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOADD_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOXOR_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOAND_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOOR_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOMIN_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOMAX_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOMINU_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)
    case AMOMAXU_D(rd: Register, rs1: Register, rs2: Register, aq: InstrField, rl: InstrField)

    case None // Instruction not found
}

public enum DecodeA64 {
    /// Decode 'A64' instructions
    public static func Decode(_ instr: InstrField) -> InstructionA64 {
        let opcode = instr.bitSlice(6, 0)
        // Register number can be: 0-32
        let rd = instr.bitSlice(11, 7)
        let rs1 = instr.bitSlice(19, 15)
        let rs2 = instr.bitSlice(24, 20)

        let funct3 = instr.bitSlice(14, 12)
        let funct7 = instr.bitSlice(31, 27)

        let rl = instr.bitSlice(25, 25)
        let aq = instr.bitSlice(26, 26)

        switch opcode {
        case 0b0101111 where funct3 == 0b011:
            switch funct7 {
            case 0b00010: return .LR_D(rd: rd, rs1: rs1, aq: aq, rl: rl)
            case 0b00011: return .SC_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b00001: return .AMOSWAP_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b00000: return .AMOADD_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b00100: return .AMOXOR_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b01100: return .AMOAND_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b01000: return .AMOOR_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b10000: return .AMOMIN_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b10100: return .AMOMAX_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b11000: return .AMOMINU_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            case 0b11100: return .AMOMAXU_D(rd: rd, rs1: rs1, rs2: rs2, aq: aq, rl: rl)
            default: return .None
            }

        default: return .None
        }
    }

    public static func verbosityMessage(_ instr: InstrField, _ decodedInstr: InstructionA64, _ mstate: borrowing MachineState) {
        let fullName = String(describing: decodedInstr)
        let typeName = String(fullName.prefix(while: { $0 != "(" }))
        let instrMsg =
            switch decodedInstr {
            case let .LR_D(rd, rs1, _, _):
                String(format: "x%d, x%d", rd, rs1)
            case let .SC_D(rd, rs1, rs2, _, _), let .AMOSWAP_D(rd, rs1, rs2, _, _),
                 let .AMOADD_D(rd, rs1, rs2, _, _), let .AMOXOR_D(rd, rs1, rs2, _, _),
                 let .AMOAND_D(rd, rs1, rs2, _, _), let .AMOOR_D(rd, rs1, rs2, _, _),
                 let .AMOMIN_D(rd, rs1, rs2, _, _), let .AMOMAX_D(rd, rs1, rs2, _, _),
                 let .AMOMINU_D(rd, rs1, rs2, _, _), let .AMOMAXU_D(rd, rs1, rs2, _, _):
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
