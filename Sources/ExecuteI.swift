import Foundation

extension InstructionI: ExecuteInstruction {
    /// `SUB` - Sub operation
    func execSUB(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rdVal = mstate.getRegister(rs1) - mstate.getRegister(rs2)
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `SLL` - Shift Logical Left
    /// 
    /// ## Details
    ///
    /// `SLL`, `SRL`, and `SRA` perform logical left, logical right, and arithmetic right shifts on the value in register
    /// `rs1` by the shift amount held in register `rs2`. In `RV64I`, only the low 6 bits of rs2 are considered for the
    /// shift amount.
    func execSLL(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal = switch (rs1Val, rs2Val) {
        case let (.x32(reg), .x32(shiftAmount)):
            MachineValue(from: reg << shiftAmount)
        case let (.x64(reg), .x64(shiftAmount)):
            MachineValue(from: reg << (shiftAmount & 0x3f))
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `SRL` - Shift Right Logical
    ///
    /// ## Details
    ///
    /// `SLL`, `SRL`, and `SRA` perform logical left, logical right, and arithmetic right shifts on the value in register
    /// `rs1` by the shift amount held in register `rs2`. In `RV64I`, only the low 6 bits of rs2 are considered for the
    /// shift amount.
    func execSRL(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal = switch (rs1Val, rs2Val) {
        case let (.x32(reg1), .x32(shiftAmount)):
            MachineValue(from: reg1 >> shiftAmount)
        case let (.x64(reg1), .x64(shiftAmount)):
            MachineValue(from: reg1 >> (shiftAmount & 0x3f))
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `SRA` - Shift Right Arithmetic
    ///
    /// ## Details
    ///
    /// `SLL`, `SRL`, and `SRA` perform logical left, logical right, and arithmetic right shifts on the value in register
    /// `rs1` by the shift amount held in register `rs2`. In `RV64I`, only the low 6 bits of rs2 are considered for the
    /// shift amount.
    func execSRA(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal = switch (rs1Val, rs2Val) {
        case let (.x32(reg1), .x32(shiftAmount)):
            MachineValue(from: UInt32(bitPattern: Int32(bitPattern: reg1) >> shiftAmount))
        case let (.x64(reg1), .x64(shiftAmount)):
            MachineValue(from: UInt64(bitPattern: Int64(bitPattern: reg1) >> (shiftAmount & 0x3f)))
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }


    /// `SLT` - Set 1 if Less Then
    func execSLT(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal: UInt32 = switch (rs1Val, rs2Val) {
        case let (.x32(reg1), .x32(reg2)):
            Int32(bitPattern: reg1) < Int32(bitPattern: reg2) ? 1 : 0
        case let (.x64(reg1), .x64(reg2)):
            Int64(bitPattern: reg1) < Int64(bitPattern: reg2) ? 1 : 0
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// SLTU - Set to 1 if Less Then Unsign Immediate
    func execSLTU(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rdVal: UInt32 = mstate.getRegister(rs1) < mstate.getRegister(rs2) ? 1 : 0
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `XOR` - Xor operation
    func execXOR(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal = switch (rs1Val, rs2Val) {
        case let (.x32(reg1), .x32(reg2)):
            MachineValue(from: reg1 ^ reg2)
        case let (.x64(reg1), .x64(reg2)):
            MachineValue(from: reg1 ^ reg2)
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `OR` - Or operation
    func execOR(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal = switch (rs1Val, rs2Val) {
        case let (.x32(reg1), .x32(reg2)):
            MachineValue(from: reg1 | reg2)
        case let (.x64(reg1), .x64(reg2)):
            MachineValue(from: reg1 | reg2)
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `AND` - And operation
    func execAND(rd: Register, rs1: Register, rs2: Register, mstate: inout MachineState) {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal = switch (rs1Val, rs2Val) {
        case let (.x32(reg1), .x32(reg2)):
            MachineValue(from: reg1 & reg2)
        case let (.x64(reg1), .x64(reg2)):
            MachineValue(from: reg1 & reg2)
        default: fatalError("Unexpected behaviour")
        }
        mstate.setRegister(rd, rdVal)
        mstate.incPC()
    }

    /// `FENCE` - Fence operation (no operations)
    func execFENCE(mstate: inout MachineState) {
        mstate.incPC()
    }

    /// `ECALL` - ECALL operation
    func execECALL(mstate: inout MachineState) {
        // mstate.setRunState(.Trap(.ECall))
    }

    /// `BREAK` - BREAK operation
    func execEBREAK(mstate: inout MachineState) {
        // mstate.setRunState(.Trap(.EBreak))
    }

    /// Execute instruction
    func execute(state ms: inout MachineState) {
        switch self {
        case let .sub(rd, rs1, rs2): execSUB(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case let .sll(rd, rs1, rs2): execSLL(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case let .slt(rd, rs1, rs2): execSLT(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case let .sltu(rd, rs1, rs2): execSLTU(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case let .xor(rd, rs1, rs2): execXOR(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case let .or(rd, rs1, rs2): execOR(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case let .and(rd, rs1, rs2): execAND(rd: rd, rs1: rs1, rs2: rs2, mstate: &ms)
        case .fence: execFENCE(mstate: &ms)
        default: print("pass")
        }
    }
}
