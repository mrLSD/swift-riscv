// Replica of riscv-fs `DecodeI.fs` (module ISA.RISCV.Decode.I)

import Foundation

//================================================================
// 'I' (Integer x32 instruction set)
public enum InstructionI: Sendable, Equatable {
    case LUI(rd: Register, imm20: InstrField)
    case AUIPC(rd: Register, imm20: InstrField)

    case JALR(rd: Register, rs1: Register, imm12: InstrField)
    case JAL(rd: Register, imm20: InstrField)

    case BEQ(rs1: Register, rs2: Register, imm12: InstrField)
    case BNE(rs1: Register, rs2: Register, imm12: InstrField)
    case BLT(rs1: Register, rs2: Register, imm12: InstrField)
    case BGE(rs1: Register, rs2: Register, imm12: InstrField)
    case BLTU(rs1: Register, rs2: Register, imm12: InstrField)
    case BGEU(rs1: Register, rs2: Register, imm12: InstrField)

    case LB(rd: Register, rs1: Register, imm12: InstrField)
    case LH(rd: Register, rs1: Register, imm12: InstrField)
    case LW(rd: Register, rs1: Register, imm12: InstrField)
    case LBU(rd: Register, rs1: Register, imm12: InstrField)
    case LHU(rd: Register, rs1: Register, imm12: InstrField)

    case SB(rs1: Register, rs2: Register, imm12: InstrField)
    case SH(rs1: Register, rs2: Register, imm12: InstrField)
    case SW(rs1: Register, rs2: Register, imm12: InstrField)

    case ADDI(rd: Register, rs1: Register, imm12: InstrField)
    case SLTI(rd: Register, rs1: Register, imm12: InstrField)
    case SLTIU(rd: Register, rs1: Register, imm12: InstrField)
    case XORI(rd: Register, rs1: Register, imm12: InstrField)
    case ORI(rd: Register, rs1: Register, imm12: InstrField)
    case ANDI(rd: Register, rs1: Register, imm12: InstrField)

    case SLLI(rd: Register, rs1: Register, shamt: InstrField)
    case SRLI(rd: Register, rs1: Register, shamt: InstrField)
    case SRAI(rd: Register, rs1: Register, shamt: InstrField)

    case ADD(rd: Register, rs1: Register, rs2: Register)
    case SUB(rd: Register, rs1: Register, rs2: Register)
    case SLL(rd: Register, rs1: Register, rs2: Register)
    case SLT(rd: Register, rs1: Register, rs2: Register)
    case SLTU(rd: Register, rs1: Register, rs2: Register)
    case XOR(rd: Register, rs1: Register, rs2: Register)
    case SRL(rd: Register, rs1: Register, rs2: Register)
    case SRA(rd: Register, rs1: Register, rs2: Register)
    case OR(rd: Register, rs1: Register, rs2: Register)
    case AND(rd: Register, rs1: Register, rs2: Register)

    case FENCE(pred: InstrField, succ: InstrField, fm: InstrField)
    case ECALL
    case EBREAK

    case None // Instruction not found
}

public enum DecodeI {
    /// Decode 'I' instructions
    public static func Decode(_ mstate: borrowing MachineState, _ instr: InstrField) -> InstructionI {
        let opcode = instr.bitSlice(6, 0)
        // Register number can be: 0-32
        let rd = instr.bitSlice(11, 7)
        let rs1 = instr.bitSlice(19, 15)
        let rs2 = instr.bitSlice(24, 20)

        let funct3 = instr.bitSlice(14, 12)
        let funct7 = instr.bitSlice(31, 25)

        // Shamt funcs
        let shamt =
            if mstate.Arch.archBits == .RV32 {
                instr.bitSlice(24, 20)
            } else {
                instr.bitSlice(25, 20)
            }
        let funct6 = instr.bitSlice(31, 26)
        let shamt_ok =
            instr.bitSlice(25, 25) == 0 ||
            mstate.Arch.archBits == .RV64

        let imm12_I = instr.bitSlice(31, 20).signExtend(12)
        let imm20_U = (instr.bitSlice(31, 12) << 12).signExtend(32)

        let imm11_S =
            (
                (instr.bitSlice(31, 25) << 5) |
                instr.bitSlice(11, 7)
            ).signExtend(12)

        let imm12_B =
            (
                (instr.bitSlice(31, 31) << 12) |
                (instr.bitSlice(30, 25) << 5) |
                (instr.bitSlice(11, 8) << 1) |
                (instr.bitSlice(7, 7) << 11)
            ).signExtend(13)

        let imm20_J =
            (
                (instr.bitSlice(31, 31) << 20) |
                (instr.bitSlice(30, 21) << 1) |
                (instr.bitSlice(20, 20) << 11) |
                (instr.bitSlice(19, 12) << 12)
            ).signExtend(21)

        // Fence
        let fm = instr.bitSlice(31, 28)
        let pred = instr.bitSlice(27, 24)
        let succ = instr.bitSlice(23, 20)

        switch opcode {
        // Upper Immediate Opcodes
        case 0b0110111: return .LUI(rd: rd, imm20: imm20_U)
        case 0b0010111: return .AUIPC(rd: rd, imm20: imm20_U)

        // Jump Opcodes
        case 0b1100111: return .JALR(rd: rd, rs1: rs1, imm12: imm12_I)
        case 0b1101111: return .JAL(rd: rd, imm20: imm20_J)

        // Branch Opcodes
        case 0b1100011:
            switch funct3 {
            case 0b000: return .BEQ(rs1: rs1, rs2: rs2, imm12: imm12_B)
            case 0b001: return .BNE(rs1: rs1, rs2: rs2, imm12: imm12_B)
            case 0b100: return .BLT(rs1: rs1, rs2: rs2, imm12: imm12_B)
            case 0b101: return .BGE(rs1: rs1, rs2: rs2, imm12: imm12_B)
            case 0b110: return .BLTU(rs1: rs1, rs2: rs2, imm12: imm12_B)
            case 0b111: return .BGEU(rs1: rs1, rs2: rs2, imm12: imm12_B)
            default: return .None
            }

        // Load Opcodes
        case 0b0000011:
            switch funct3 {
            case 0b000: return .LB(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b001: return .LH(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b010: return .LW(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b100: return .LBU(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b101: return .LHU(rd: rd, rs1: rs1, imm12: imm12_I)
            default: return .None
            }

        // Store opcodes
        case 0b0100011:
            switch funct3 {
            case 0b000: return .SB(rs1: rs1, rs2: rs2, imm12: imm11_S)
            case 0b001: return .SH(rs1: rs1, rs2: rs2, imm12: imm11_S)
            case 0b010: return .SW(rs1: rs1, rs2: rs2, imm12: imm11_S)
            default: return .None
            }

        // Immediate Opcodes
        case 0b0010011:
            switch funct3 {
            case 0b000: return .ADDI(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b010: return .SLTI(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b011: return .SLTIU(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b100: return .XORI(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b110: return .ORI(rd: rd, rs1: rs1, imm12: imm12_I)
            case 0b111: return .ANDI(rd: rd, rs1: rs1, imm12: imm12_I)

            // Shift Immediate Opcodes
            case 0b001 where funct6 == 0b000000 && shamt_ok: return .SLLI(rd: rd, rs1: rs1, shamt: shamt)
            case 0b101 where funct6 == 0b000000 && shamt_ok: return .SRLI(rd: rd, rs1: rs1, shamt: shamt)
            case 0b101 where funct6 == 0b010000 && shamt_ok: return .SRAI(rd: rd, rs1: rs1, shamt: shamt)
            default: return .None
            }

        // ALU Opcodes
        case 0b0110011:
            switch funct3 {
            case 0b000 where funct7 == 0b0000000: return .ADD(rd: rd, rs1: rs1, rs2: rs2)
            case 0b000 where funct7 == 0b0100000: return .SUB(rd: rd, rs1: rs1, rs2: rs2)
            case 0b001 where funct7 == 0b0000000: return .SLL(rd: rd, rs1: rs1, rs2: rs2)
            case 0b010 where funct7 == 0b0000000: return .SLT(rd: rd, rs1: rs1, rs2: rs2)
            case 0b011 where funct7 == 0b0000000: return .SLTU(rd: rd, rs1: rs1, rs2: rs2)
            case 0b100 where funct7 == 0b0000000: return .XOR(rd: rd, rs1: rs1, rs2: rs2)
            case 0b101 where funct7 == 0b0000000: return .SRL(rd: rd, rs1: rs1, rs2: rs2)
            case 0b101 where funct7 == 0b0100000: return .SRA(rd: rd, rs1: rs1, rs2: rs2)
            case 0b110 where funct7 == 0b0000000: return .OR(rd: rd, rs1: rs1, rs2: rs2)
            case 0b111 where funct7 == 0b0000000: return .AND(rd: rd, rs1: rs1, rs2: rs2)
            default: return .None
            }

        // Fence Opcode. The rd/rs1 fields are reserved for finer-grain fences; a base
        // implementation ignores them (per spec) rather than rejecting the instruction.
        case 0b0001111 where funct3 == 0b000: return .FENCE(pred: pred, succ: succ, fm: fm)

        // System opcodes
        case 0b1110011 where rd == 0 && rs1 == 0 && funct3 == 0b000 && imm12_I == 0b000000000000: return .ECALL
        case 0b1110011 where rd == 0 && rs1 == 0 && funct3 == 0b000 && imm12_I == 0b000000000001: return .EBREAK

        default: return .None
        }
    }

    /// Current ISA print log message for current instruction step
    public static func verbosityMessage(_ instr: InstrField, _ decodedInstr: InstructionI, _ mstate: borrowing MachineState) {
        let fullName = String(describing: decodedInstr)
        let typeName = String(fullName.prefix(while: { $0 != "(" }))
        let instrMsg =
            switch decodedInstr {
            case let .LUI(rd, imm20), let .AUIPC(rd, imm20):
                String(format: "x%d, 0x%08x", rd, imm20)
            case let .JAL(rd, imm20):
                String(format: "x%d, 0x%08x\n", rd, imm20)
            case let .JALR(rd, rs1, imm12):
                String(format: "x%d, x%d, 0x%08x\n", rd, rs1, imm12)
            case let .LB(rd, rs1, imm12), let .LH(rd, rs1, imm12), let .LW(rd, rs1, imm12),
                 let .LBU(rd, rs1, imm12), let .LHU(rd, rs1, imm12),
                 let .ADDI(rd, rs1, imm12), let .SLTI(rd, rs1, imm12), let .XORI(rd, rs1, imm12),
                 let .ORI(rd, rs1, imm12), let .ANDI(rd, rs1, imm12):
                String(format: "x%d, x%d, %d", rd, rs1, imm12)
            case let .BEQ(rs1, rs2, imm12), let .BNE(rs1, rs2, imm12), let .BLT(rs1, rs2, imm12),
                 let .BGE(rs1, rs2, imm12), let .BLTU(rs1, rs2, imm12), let .BGEU(rs1, rs2, imm12),
                 let .SB(rs1, rs2, imm12), let .SH(rs1, rs2, imm12), let .SW(rs1, rs2, imm12):
                String(format: "x%d, x%d, 0x%08x", rs1, rs2, imm12)
            case let .SLLI(rd, rs1, shamt), let .SRLI(rd, rs1, shamt), let .SRAI(rd, rs1, shamt):
                String(format: "x%d, x%d, %d", rd, rs1, shamt)
            case let .ADD(rd, rs1, rs2), let .SUB(rd, rs1, rs2), let .SLL(rd, rs1, rs2),
                 let .SLT(rd, rs1, rs2), let .SLTU(rd, rs1, rs2), let .XOR(rd, rs1, rs2),
                 let .SRL(rd, rs1, rs2), let .SRA(rd, rs1, rs2), let .OR(rd, rs1, rs2),
                 let .AND(rd, rs1, rs2):
                String(format: "x%d, x%d, x%d", rd, rs1, rs2)
            case .FENCE, .EBREAK, .ECALL:
                ""
            // The reference's wildcard arm: None — and SLTIU, which the reference
            // pattern list also omits — print as "Undef".
            default:
                "Undef"
            }
        let pc = String(format: "%08llx:", mstate.PC)
        let instr = String(format: "%08x", instr)
        let msg = padRight(typeName, 7) + instrMsg
        Swift.print(padRight(pc, 12) + padRight(instr, 12) + msg)
    }
}
