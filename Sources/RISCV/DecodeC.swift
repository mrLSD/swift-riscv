// Replica of riscv-fs `DecodeC.fs` (module ISA.RISCV.Decode.C)

import Foundation

//================================================================
// 'C'  (Compressed 16-bit instructions 'C' Standard Extension)
// Each compressed instruction is the short form of a base instruction;
// Decode expands the operands so Execute can reuse the base semantics.
// FP-compressed loads/stores: the reference decodes the Zcf set
// (C.FLW/C.FSW/C.FLWSP/C.FSWSP, RV32-only) when the architecture has F;
// F is not implemented in this port, so those encodings remain reserved
// and decode to None — exactly the pattern the reference itself applies
// to the Zcd set (C.FLD/C.FSD/C.FLDSP/C.FSDSP, which requires D).
public enum InstructionC: Sendable, Equatable {
    case C_ADDI4SPN(rd: Register, imm: InstrField)
    case C_LW(rd: Register, rs1: Register, imm: InstrField)
    case C_LD(rd: Register, rs1: Register, imm: InstrField)
    case C_SW(rs1: Register, rs2: Register, imm: InstrField)
    case C_SD(rs1: Register, rs2: Register, imm: InstrField)
    case C_ADDI(rd: Register, imm: InstrField)
    case C_ADDIW(rd: Register, imm: InstrField)
    case C_LI(rd: Register, imm: InstrField)
    case C_LUI(rd: Register, imm: InstrField)
    case C_ADDI16SP(imm: InstrField)
    case C_SRLI(rd: Register, shamt: InstrField)
    case C_SRAI(rd: Register, shamt: InstrField)
    case C_ANDI(rd: Register, imm: InstrField)
    case C_SUB(rd: Register, rs2: Register)
    case C_XOR(rd: Register, rs2: Register)
    case C_OR(rd: Register, rs2: Register)
    case C_AND(rd: Register, rs2: Register)
    case C_SUBW(rd: Register, rs2: Register)
    case C_ADDW(rd: Register, rs2: Register)
    case C_J(imm: InstrField)
    case C_JAL(imm: InstrField)
    case C_BEQZ(rs1: Register, imm: InstrField)
    case C_BNEZ(rs1: Register, imm: InstrField)
    case C_SLLI(rd: Register, shamt: InstrField)
    case C_LWSP(rd: Register, imm: InstrField)
    case C_LDSP(rd: Register, imm: InstrField)
    case C_JR(rs1: Register)
    case C_JALR(rs1: Register)
    case C_MV(rd: Register, rs2: Register)
    case C_ADD(rd: Register, rs2: Register)
    case C_EBREAK
    case C_SWSP(rs2: Register, imm: InstrField)
    case C_SDSP(rs2: Register, imm: InstrField)
    case None // Instruction not found
}

public enum DecodeC {
    /// CJ-format immediate (C.J / C.JAL), sign-extended 12-bit
    private static func cjImm(_ instr: InstrField) -> InstrField {
        ((instr.bitSlice(12, 12) << 11) | (instr.bitSlice(8, 8) << 10) | (instr.bitSlice(10, 9) << 8)
            | (instr.bitSlice(6, 6) << 7) | (instr.bitSlice(7, 7) << 6) | (instr.bitSlice(2, 2) << 5)
            | (instr.bitSlice(11, 11) << 4) | (instr.bitSlice(5, 3) << 1)).signExtend(12)
    }

    /// CB-format immediate (C.BEQZ / C.BNEZ), sign-extended 9-bit
    private static func cbImm(_ instr: InstrField) -> InstrField {
        ((instr.bitSlice(12, 12) << 8) | (instr.bitSlice(6, 5) << 6) | (instr.bitSlice(2, 2) << 5)
            | (instr.bitSlice(11, 10) << 3) | (instr.bitSlice(4, 3) << 1)).signExtend(9)
    }

    /// Decode 'C' (compressed) instructions
    public static func Decode(_ mstate: borrowing MachineState, _ instr: InstrField) -> InstructionC {
        let rv64 = mstate.Arch.archBits == .RV64
        let op = instr.bitSlice(1, 0)
        let funct3 = instr.bitSlice(15, 13)
        // 3-bit compressed register operands map to x8..x15
        let rdc = instr.bitSlice(4, 2) + 8 // rd'/rs2' field at [4:2]
        let rs1c = instr.bitSlice(9, 7) + 8 // rs1'/rd'  field at [9:7]
        // wide register operands
        let rdw = instr.bitSlice(11, 7)
        let rs2w = instr.bitSlice(6, 2)
        // shamt for CI/CB shifts (6-bit; RV32 requires bit 5 = 0)
        let shamt = (instr.bitSlice(12, 12) << 5) | instr.bitSlice(6, 2)
        let shamtOk = rv64 || instr.bitSlice(12, 12) == 0
        let imm6 = ((instr.bitSlice(12, 12) << 5) | instr.bitSlice(6, 2)).signExtend(6)

        switch op {
        // ---- Quadrant 0 ----
        case 0b00:
            switch funct3 {
            case 0b000: // C.ADDI4SPN -> addi rd', x2, nzuimm
                let imm = (instr.bitSlice(10, 7) << 6) | (instr.bitSlice(12, 11) << 4)
                    | (instr.bitSlice(5, 5) << 3) | (instr.bitSlice(6, 6) << 2)
                return imm == 0 ? .None : .C_ADDI4SPN(rd: rdc, imm: imm)
            case 0b010: // C.LW
                let imm = (instr.bitSlice(5, 5) << 6) | (instr.bitSlice(12, 10) << 3) | (instr.bitSlice(6, 6) << 2)
                return .C_LW(rd: rdc, rs1: rs1c, imm: imm)
            case 0b110: // C.SW
                let imm = (instr.bitSlice(5, 5) << 6) | (instr.bitSlice(12, 10) << 3) | (instr.bitSlice(6, 6) << 2)
                return .C_SW(rs1: rs1c, rs2: rdc, imm: imm)
            case 0b011 where rv64: // C.LD
                let imm = (instr.bitSlice(6, 5) << 6) | (instr.bitSlice(12, 10) << 3)
                return .C_LD(rd: rdc, rs1: rs1c, imm: imm)
            case 0b111 where rv64: // C.SD
                let imm = (instr.bitSlice(6, 5) << 6) | (instr.bitSlice(12, 10) << 3)
                return .C_SD(rs1: rs1c, rs2: rdc, imm: imm)
            // funct3 = 011/111 without rv64 would be C.FLW/C.FSW (Zcf, needs F);
            // funct3 = 001/101 would be C.FLD/C.FSD (Zcd, needs D) — all reserved here.
            default:
                return .None
            }

        // ---- Quadrant 1 ----
        case 0b01:
            switch funct3 {
            case 0b000: // C.NOP / C.ADDI
                return .C_ADDI(rd: rdw, imm: imm6)
            case 0b001 where !rv64: // C.JAL (RV32)
                return .C_JAL(imm: cjImm(instr))
            case 0b001: // C.ADDIW (RV64)
                return rdw == 0 ? .None : .C_ADDIW(rd: rdw, imm: imm6)
            case 0b010: // C.LI
                return .C_LI(rd: rdw, imm: imm6)
            case 0b011: // C.ADDI16SP (rd=2) / C.LUI (rd!=2)
                if rdw == 2 {
                    let imm = ((instr.bitSlice(12, 12) << 9) | (instr.bitSlice(4, 3) << 7)
                        | (instr.bitSlice(5, 5) << 6) | (instr.bitSlice(2, 2) << 5)
                        | (instr.bitSlice(6, 6) << 4)).signExtend(10)
                    return imm == 0 ? .None : .C_ADDI16SP(imm: imm)
                }
                // nzimm=0 is reserved; rd=x0 (nzimm!=0) is a HINT -> decode as C_LUI rd=0,
                // which executes as a write to x0 (no-op), per the C-extension HINT rules.
                else if imm6 == 0 {
                    return .None
                } else {
                    return .C_LUI(rd: rdw, imm: imm6 << 12)
                }
            case 0b100: // misc-ALU
                switch instr.bitSlice(11, 10) {
                case 0b00: return shamtOk ? .C_SRLI(rd: rs1c, shamt: shamt) : .None
                case 0b01: return shamtOk ? .C_SRAI(rd: rs1c, shamt: shamt) : .None
                case 0b10: return .C_ANDI(rd: rs1c, imm: imm6)
                default: // 0b11: CA-format register-register
                    switch (instr.bitSlice(12, 12), instr.bitSlice(6, 5)) {
                    case (0, 0b00): return .C_SUB(rd: rs1c, rs2: rdc)
                    case (0, 0b01): return .C_XOR(rd: rs1c, rs2: rdc)
                    case (0, 0b10): return .C_OR(rd: rs1c, rs2: rdc)
                    case (0, 0b11): return .C_AND(rd: rs1c, rs2: rdc)
                    case (1, 0b00) where rv64: return .C_SUBW(rd: rs1c, rs2: rdc)
                    case (1, 0b01) where rv64: return .C_ADDW(rd: rs1c, rs2: rdc)
                    default: return .None
                    }
                }
            case 0b101: return .C_J(imm: cjImm(instr))
            case 0b110: return .C_BEQZ(rs1: rs1c, imm: cbImm(instr))
            default: return .C_BNEZ(rs1: rs1c, imm: cbImm(instr)) // funct3 = 0b111
            }

        // ---- Quadrant 2 ----
        case 0b10:
            switch funct3 {
            case 0b000: // C.SLLI
                return shamtOk ? .C_SLLI(rd: rdw, shamt: shamt) : .None
            case 0b010: // C.LWSP (rd != 0)
                let imm = (instr.bitSlice(3, 2) << 6) | (instr.bitSlice(12, 12) << 5) | (instr.bitSlice(6, 4) << 2)
                return rdw == 0 ? .None : .C_LWSP(rd: rdw, imm: imm)
            case 0b011 where rv64: // C.LDSP (rd != 0)
                let imm = (instr.bitSlice(4, 2) << 6) | (instr.bitSlice(12, 12) << 5) | (instr.bitSlice(6, 5) << 3)
                return rdw == 0 ? .None : .C_LDSP(rd: rdw, imm: imm)
            case 0b100: // CR-format: C.JR / C.MV / C.EBREAK / C.JALR / C.ADD
                switch (instr.bitSlice(12, 12), rdw, rs2w) {
                case (0, _, 0): return rdw == 0 ? .None : .C_JR(rs1: rdw)
                case (0, _, _): return .C_MV(rd: rdw, rs2: rs2w)
                case (_, 0, 0): return .C_EBREAK
                case (_, _, 0): return .C_JALR(rs1: rdw)
                default: return .C_ADD(rd: rdw, rs2: rs2w)
                }
            case 0b110: // C.SWSP
                let imm = (instr.bitSlice(8, 7) << 6) | (instr.bitSlice(12, 9) << 2)
                return .C_SWSP(rs2: rs2w, imm: imm)
            case 0b111 where rv64: // C.SDSP
                let imm = (instr.bitSlice(9, 7) << 6) | (instr.bitSlice(12, 10) << 3)
                return .C_SDSP(rs2: rs2w, imm: imm)
            // funct3 = 011/111 without rv64 would be C.FLWSP/C.FSWSP (Zcf, needs F);
            // funct3 = 001/101 would be C.FLDSP/C.FSDSP (Zcd, needs D) — reserved here.
            default:
                return .None
            }

        default:
            return .None
        }
    }

    /// Current ISA print log message for current instruction step
    public static func verbosityMessage(_ instr: InstrField, _ decodedInstr: InstructionC, _ mstate: borrowing MachineState) {
        let fullName = String(describing: decodedInstr)
        let typeName = String(fullName.prefix(while: { $0 != "(" }))
        let instrMsg =
            switch decodedInstr {
            case let .C_ADDI4SPN(rd, imm), let .C_ADDI(rd, imm), let .C_ADDIW(rd, imm),
                 let .C_LI(rd, imm), let .C_LUI(rd, imm), let .C_ANDI(rd, imm),
                 let .C_LWSP(rd, imm), let .C_LDSP(rd, imm):
                String(format: "x%d, %d", rd, imm)
            case let .C_LW(rd, rs1, imm), let .C_LD(rd, rs1, imm):
                String(format: "x%d, %d(x%d)", rd, imm, rs1)
            case let .C_SW(rs1, rs2, imm), let .C_SD(rs1, rs2, imm):
                String(format: "x%d, %d(x%d)", rs2, imm, rs1)
            case let .C_SRLI(rd, shamt), let .C_SRAI(rd, shamt), let .C_SLLI(rd, shamt):
                String(format: "x%d, %d", rd, shamt)
            case let .C_SUB(rd, rs2), let .C_XOR(rd, rs2), let .C_OR(rd, rs2), let .C_AND(rd, rs2),
                 let .C_SUBW(rd, rs2), let .C_ADDW(rd, rs2), let .C_MV(rd, rs2), let .C_ADD(rd, rs2):
                String(format: "x%d, x%d", rd, rs2)
            case let .C_J(imm), let .C_JAL(imm), let .C_ADDI16SP(imm):
                String(format: "%d", imm)
            case let .C_BEQZ(rs1, imm), let .C_BNEZ(rs1, imm):
                String(format: "x%d, %d", rs1, imm)
            case let .C_JR(rs1), let .C_JALR(rs1):
                String(format: "x%d", rs1)
            case let .C_SWSP(rs2, imm), let .C_SDSP(rs2, imm):
                String(format: "x%d, %d(x2)", rs2, imm)
            // The reference's wildcard arm: None and C_EBREAK print as "Undef".
            default:
                "Undef"
            }
        let pc = String(format: "%08llx:", mstate.PC)
        let instr = String(format: "%04x", instr)
        let msg = padRight(typeName, 7) + instrMsg
        Swift.print(padRight(pc, 12) + padRight(instr, 12) + msg)
    }
}
