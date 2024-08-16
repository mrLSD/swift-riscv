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
        let opcode = instr & 0x7F
        // [11:7]
        let rd = (instr >> 7) & 0x1F
        // [19:15]
        let rs1 = (instr >> 15) & 0x1F
        // [24:20]
        let rs2 = (instr >> 20) & 0x1F

        // [14:12]
        let funct3 = (instr >> 12) & 0x7
        // [31:25]
        let funct7 = (instr >> 25) & 0x7F

        // I-type immediate
        // [31:20], sign extended
        let imm12_i = signExtend(instr >> 20, 20)

        // U-type immediate
        // [31:12] << 12, sign extend
        let imm20_u = signExtend(instr & 0xFFFF_F000, 0)

        // J-type immediate
        // [31, 19:12, 20, 30:21, 0b0], sign extended -
        let imm20_j =
            // [31] -> [20] (& 0b1_0000_0000_0000_0000_0000)
            signExtend((instr >> 11) & 0x10_0000, 11) |
            // [19:12] -> [19:12] (& 0b1111_1111_0000_0000_0000)
            (instr & 0xFF000) |
            // [20] -> [11] (& 1000_0000_0000)
            ((instr >> 9) & 0x800) |
            // [30:21] -> [10:1] (& 0b111_1111_1110)
            ((instr >> 20) & 0x7FE)

        // B-type immediate
        // [31, 7, 30:25, 11:8, 0b0], sign extended
        let imm12_b =
            // [31] -> [12] (& 0b1_0000_0000_0000)
            signExtend((instr >> 19) & 0x1000, 19) |
            // [7] -> [11] (& 0b1000_0000_0000)
            ((instr << 4) & 0x800) |
            // [30:25] -> [10:5] (& 0b111_1110_0000)
            ((instr >> 20) & 0x7E0) |
            // [11:8] -> [4:1] (& 0b1_1110)
            ((instr >> 7) & 0x1E)

        // S-type immediate
        // [31:25, 11:7], sign extended
        let imm12_s =
            // [31:25] -> [11:5] (& 0b1111_1110_0000)
            signExtend((instr >> 20) & 0xFE0, 20) |
            // [11:7] -> [4:0] (& 0b1_1111)
            ((instr >> 7) & 0x1F)

        // Shift: shamt funcs
        let shamt = (instr >> 20) & 0x3F
        let funct6 = funct7 >> 1

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
        // Store opcodes
        case 0b0100011:
            switch funct3 {
            case 0b000: .sb(rs1: rs1, rs2: rs2, imm12: imm12_s)
            case 0b001: .sh(rs1: rs1, rs2: rs2, imm12: imm12_s)
            case 0b010: .sw(rs1: rs1, rs2: rs2, imm12: imm12_s)
            default: nil
            }
        // Immediate Opcodes
        case 0b0010011:
            switch funct3 {
            case 0b000: .addi(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b010: .slti(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b011: .sltiu(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b100: .xori(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b110: .ori(rd: rd, rs1: rs1, imm12: imm12_i)
            case 0b111: .andi(rd: rd, rs1: rs1, imm12: imm12_i)
            // Shift Immediate Opcodes
            case 0b001: .slli(rd: rd, rs1: rs1, shamt: shamt)
            case 0b101 where funct6 == 0b000000: .srli(rd: rd, rs1: rs1, shamt: shamt)
            case 0b101 where funct6 == 0b100000: .srai(rd: rd, rs1: rs1, shamt: shamt)
            default: nil
            }
        // ALU Opcodes
        case 0b0110011:
            switch funct3 {
            case 0b000 where funct7 == 0b0000000: .add(rd: rd, rs1: rs1, rs2: rs2)
            case 0b000 where funct7 == 0b0100000: .sub(rd: rd, rs1: rs1, rs2: rs2)
            case 0b001 where funct7 == 0b0000000: .sll(rd: rd, rs1: rs1, rs2: rs2)
            case 0b010 where funct7 == 0b0000000: .slt(rd: rd, rs1: rs1, rs2: rs2)
            case 0b011 where funct7 == 0b0000000: .sltu(rd: rd, rs1: rs1, rs2: rs2)
            case 0b100 where funct7 == 0b0000000: .xor(rd: rd, rs1: rs1, rs2: rs2)
            case 0b101 where funct7 == 0b0000000: .srl(rd: rd, rs1: rs1, rs2: rs2)
            case 0b101 where funct7 == 0b0100000: .sra(rd: rd, rs1: rs1, rs2: rs2)
            case 0b110 where funct7 == 0b0000000: .or(rd: rd, rs1: rs1, rs2: rs2)
            case 0b111 where funct7 == 0b0000000: .and(rd: rd, rs1: rs1, rs2: rs2)
            default: nil
            }
        // FENCE
        case 0b0001111 where rs1 == 0 && rd == 0 && funct3 == 0b000: .and(rd: rd, rs1: rs1, rs2: rs2)
        // [31:28]
        // let fm = (instr >> 28) & 0x7
        // [27:24]
        // let pred = (instr >> 24) & 0x7
        // [23:20]
        // let succ = (instr >> 28) & 0x7
        //    .fence(pred: pred, succ: succ, fm: fm)
        default: nil
        }
        return decoded
    }
}
