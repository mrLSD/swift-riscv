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

    /// Decode instruction fir [31:0] bits
    static func decode(instr: MachineValue) -> ExecuteInstruction? {
        // Get instruction for 32-bit arch
        guard case let .x32(instr) = instr else {
            return nil
        }
        // [6:0]
        let opcode = instr & 0x0000_007F
        // [11:7]
        let rd = (instr & 0x0000_0F80) >> 7
        // [19:15]
        let rs1 = (instr & 0x000F_8000) >> 15
        // [24:20]
        let rs2 = (instr & 0x01F0_0000) >> 20

        // [14:12]
        let funct3 = (instr & 0x0000_7000) >> 12
        // [31:25]
        let funct7 = (instr & 0xFE00_0000) >> 25

//        `OPCODE_JALR:   // I-type immediate
//            immediate = { {21{inst[31]}}, inst[30:25], inst[24:20] };
//        `OPCODE_STORE_FP,
//        `OPCODE_STORE:  // S-type immediate
//            immediate = { {21{inst[31]}}, inst[30:25], inst[11:7] };
//        `OPCODE_BRANCH: // B-type immediate
//            immediate = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
//        `OPCODE_AUIPC,
//        `OPCODE_LUI:    // U-type immediate
//            immediate = { {1{inst[31]}}, inst[30:20], inst[19:12], 12'b0 };
//        `OPCODE_JAL:    // J-type immediate
//            immediate = { {12{inst[31]}}, inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0 };

        // I-type immediate
        // [31:20], sign extended
        let imm12_i = signExtend(instr >> 20, 20)

        // U-type immediate
        // [31:12] << 12, sign extend
        let imm20_u = signExtend(instr & 0xFFFF_F000, 0)

        // J-type immediate
        // [31, 19:12, 20, 30:21], sign extended
        let imm20_j =
            // [31] -> [20]
            signExtend((instr & 0x8000_0000) >> 11, 11) |
            // [19:12] -> [19:12]
            (instr & 0xFF000) |
            // [20] -> [11]
            ((instr >> 9) & 0x800) |
            // [30:21] -> [10:1]
            ((instr >> 20) & 0x7FE)

        // B-type immediate
        // [31, 7, 30:25, 11:8], sign extended
        let imm12_b =
            // [31] -> [12]
            signExtend((instr & 0x8000_0000) >> 19, 19) |
            // [7] -> [11]
            ((instr & 0x80) << 4) |
            // [30:25] -> [10:5]
            ((instr >> 20) & 0x7E0) |
            // [11:8] -> [4:1]
            ((instr >> 7) & 0x1E)

        let decoded: InstructionI? = switch opcode {
        // Upper Immediate Opcodes
        case 0b0110111: self.lui(rd: rd, imm20: imm20_u)
        case 0b0010111: self.auipc(rd: rd, imm20: imm20_u)
        // Jump Opcodes
        case 0b1100111: self.jalr(rd: rd, rs1: rs1, imm12: imm12_i)
        case 0b1101111: self.jal(rd: rd, imm20: imm20_j)
        // Branch Opcodes
        case 0b1100011:
            switch funct3 {
            case 0b000: .beq(rs1: rs1, rs2: rs2, imm12: imm12_b)
            case 0b001: .bne(rs1: rs1, rs2: rs2, imm12: imm12_b)
            case 0b100: .blt(rs1: rs1, rs2: rs2, imm12: imm12_b)
            case 0b101: .bge(rs1: rs1, rs2: rs2, imm12: imm12_b)
            case 0b110: .bltu(rs1: rs1, rs2: rs2, imm12: imm12_b)
            case 0b111: .bgeu(rs1: rs1, rs2: rs2, imm12: imm12_b)
            default: nil
            }
        // Load Opcodes
        case 0b0000011:
            switch funct3 {
            case 0b000: .lb(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b001: .lh(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b010: .lw(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b100: .lbu(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b101: .lhu(rd: rd, rs1: rs1, imm12: imm12_i)
            default: nil
            }
        default: nil
        }
        return decoded
    }
}
