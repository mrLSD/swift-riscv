// Replica of riscv-fs `DecodeM.fs` (module ISA.RISCV.Decode.M)

import Foundation

//================================================================
// 'M'  (Integer Multiplication and Division 'M' Standard Extension)
public enum InstructionM: Sendable, Equatable {
    case MUL(rd: Register, rs1: Register, rs2: Register)
    case MULH(rd: Register, rs1: Register, rs2: Register)
    case MULHSU(rd: Register, rs1: Register, rs2: Register)
    case MULHU(rd: Register, rs1: Register, rs2: Register)
    case DIV(rd: Register, rs1: Register, rs2: Register)
    case DIVU(rd: Register, rs1: Register, rs2: Register)
    case REM(rd: Register, rs1: Register, rs2: Register)
    case REMU(rd: Register, rs1: Register, rs2: Register)

    case None // Instruction not found
}

public enum DecodeM {
    /// Decode 'M' instructions
    public static func Decode(_ mstate: borrowing MachineState, _ instr: InstrField) -> InstructionM {
        let opcode = instr.bitSlice(6, 0)
        // Register number can be: 0-32
        let rd = instr.bitSlice(11, 7)
        let rs1 = instr.bitSlice(19, 15)
        let rs2 = instr.bitSlice(24, 20)

        let funct3 = instr.bitSlice(14, 12)
        let funct7 = instr.bitSlice(31, 25)

        switch opcode {
        // RV32M Standard Extension
        case 0b0110011:
            switch (funct7, funct3) {
            // Multiplication Operations
            case (0b0000001, 0b000): return .MUL(rd: rd, rs1: rs1, rs2: rs2)
            case (0b0000001, 0b001): return .MULH(rd: rd, rs1: rs1, rs2: rs2)
            case (0b0000001, 0b010): return .MULHSU(rd: rd, rs1: rs1, rs2: rs2)
            case (0b0000001, 0b011): return .MULHU(rd: rd, rs1: rs1, rs2: rs2)
            // Division Operations
            case (0b0000001, 0b100): return .DIV(rd: rd, rs1: rs1, rs2: rs2)
            case (0b0000001, 0b101): return .DIVU(rd: rd, rs1: rs1, rs2: rs2)
            case (0b0000001, 0b110): return .REM(rd: rd, rs1: rs1, rs2: rs2)
            case (0b0000001, 0b111): return .REMU(rd: rd, rs1: rs1, rs2: rs2)
            default: return .None
            }
        default: return .None
        }
    }

    /// Current ISA print log message for current instruction step
    public static func verbosityMessage(_ instr: InstrField, _ decodedInstr: InstructionM, _ mstate: borrowing MachineState) {
        let fullName = String(describing: decodedInstr)
        let typeName = String(fullName.prefix(while: { $0 != "(" }))
        let instrMsg =
            switch decodedInstr {
            case let .MUL(rd, rs1, rs2), let .MULH(rd, rs1, rs2), let .MULHSU(rd, rs1, rs2),
                 let .MULHU(rd, rs1, rs2), let .DIV(rd, rs1, rs2),
                 let .DIVU(rd, rs1, rs2), let .REM(rd, rs1, rs2), let .REMU(rd, rs1, rs2):
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
