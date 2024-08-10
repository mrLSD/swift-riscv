import Foundation

/// 'I' (Integer x32 instruction set)
enum InstructionI: DecodeInstruction {
    case lui(rd: Register, imm20: InstrField)
    case auipc(rd: Register, imm20: InstrField)

    case jalr(rd: Register, rs1: Register, imm12: InstrField)
    case jal(rd: Register, imm20: InstrField)

    case beq(rs1: Register, rs2: Register, imm12: InstrField)
    case bne(rs1: Register, rs2: Register, imm12: InstrField)
    case blt(rs1: Register, rs2: Register, imm12: InstrField)
    case bge(rs1: Register, rs2: Register, imm12: InstrField)
    case bltu(rs1: Register, rs2: Register, imm12: InstrField)
    case bgeu(rs1: Register, rs2: Register, imm12: InstrField)

    case lb(rd: Register, rs1: Register, imm12: InstrField)
    case lh(rd: Register, rs1: Register, imm12: InstrField)
    case lw(rd: Register, rs1: Register, imm12: InstrField)
    case lbu(rd: Register, rs1: Register, imm12: InstrField)
    case lhu(rd: Register, rs1: Register, imm12: InstrField)

    case sb(rs1: Register, rs2: Register, imm12: InstrField)
    case sh(rs1: Register, rs2: Register, imm12: InstrField)
    case sw(rs1: Register, rs2: Register, imm12: InstrField)

    case addi(rd: Register, rs1: Register, imm12: InstrField)
    case slti(rd: Register, rs1: Register, imm12: InstrField)
    case sltiu(rd: Register, rs1: Register, imm12: InstrField)
    case xori(rd: Register, rs1: Register, imm12: InstrField)
    case ori(rd: Register, rs1: Register, imm12: InstrField)
    case andi(rd: Register, rs1: Register, imm12: InstrField)

    case slli(rd: Register, rs1: Register, shamt: InstrField)
    case srli(rd: Register, rs1: Register, shamt: InstrField)
    case srai(rd: Register, rs1: Register, shamt: InstrField)

    case add(rd: Register, rs1: Register, rs2: Register)
    case sub(rd: Register, rs1: Register, rs2: Register)
    case sll(rd: Register, rs1: Register, rs2: Register)
    case slt(rd: Register, rs1: Register, rs2: Register)
    case sltu(rd: Register, rs1: Register, rs2: Register)
    case xor(rd: Register, rs1: Register, rs2: Register)
    case srl(rd: Register, rs1: Register, rs2: Register)
    case sra(rd: Register, rs1: Register, rs2: Register)
    case or(rd: Register, rs1: Register, rs2: Register)
    case and(rd: Register, rs1: Register, rs2: Register)

    case fence(pred: InstrField, succ: InstrField, fm: InstrField)
    case ecall
    case ebreak

    /// Decode instruction
    static func decode(instr: MachineValue) -> ExecuteInstruction? {
        nil
    }
}
