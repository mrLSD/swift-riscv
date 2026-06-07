// Replica of riscv-fs `ExecuteI.fs` (module ISA.RISCV.Execute.I)
//
// .NET integer arithmetic wraps silently; the Swift replica uses the overflow
// operators (&+, &-) and truncating conversions to reproduce that bit-for-bit.

public enum ExecuteI {
    //=================================================
    // LUI - Load Upper immediate
    static func execLUI(_ rd: Register, _ imm20: InstrField, _ mstate: consuming MachineState) -> MachineState {
        return mstate.setRegisterIncPC(rd, Int64(imm20))
    }

    //=================================================
    // AUIPC - Add Upper immediate PC
    static func execAUIPC(_ rd: Register, _ imm20: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let pc = mstate.PC
        return mstate.setRegisterIncPC(rd, Int64(imm20) &+ pc)
    }

    //=================================================
    // JALR - Jump Relative immediately
    static func execJALR(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let newPC = mstate.alignByArchUnsign((mstate.getRegister(rs1) &+ Int64(imm12)) & ~1)
        if newPC % mstate.instrAlign != 0 {
            return mstate.setRunState(.Trap(.JumpAddress))
        } else if newPC == mstate.PC {
            return mstate.setRunState(.Stopped)
        } else {
            let linkPC = mstate.PC &+ Int64(mstate.InstrLen)
            return mstate.setRegisterSetPC(rd, mstate.alignByArchUnsign(linkPC), newPC)
        }
    }

    //=================================================
    // JAL - Jump immediately
    static func execJAL(_ rd: Register, _ imm20: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let newPC = mstate.PC &+ Int64(imm20)
        if newPC % mstate.instrAlign != 0 {
            return mstate.setRunState(.Trap(.JumpAddress))
        } else if newPC == mstate.PC {
            return mstate.setRunState(.Stopped)
        } else {
            let linkPC = mstate.PC &+ Int64(mstate.InstrLen)
            return mstate.setRegisterSetPC(rd, mstate.alignByArchUnsign(linkPC), newPC)
        }
    }

    /// Basic branch flow
    static func branch(
        _ branchCheck: (MachineInt, MachineInt) -> Bool,
        _ rs1: Register, _ rs2: Register, _ imm12: InstrField,
        _ mstate: consuming MachineState
    ) -> MachineState {
        let x1 = mstate.getRegister(rs1)
        let x2 = mstate.getRegister(rs2)
        // The misalignment trap and the self-loop sentinel apply only when the
        // branch is taken; a not-taken branch always falls through to PC+InstrLen.
        if branchCheck(x1, x2) {
            let newPC = mstate.PC &+ Int64(imm12)
            if newPC % mstate.instrAlign != 0 {
                return mstate.setRunState(.Trap(.BreakAddress))
            } else if newPC == mstate.PC {
                return mstate.setRunState(.Stopped)
            } else {
                return mstate.setPC(newPC)
            }
        } else {
            return mstate.incPC()
        }
    }

    //=================================================
    // BEQ - Branch if Equal
    static func execBEQ(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        branch(==, rs1, rs2, imm12, mstate)
    }

    //=================================================
    // BNE - Branch if Not Equal
    static func execBNE(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        branch(!=, rs1, rs2, imm12, mstate)
    }

    //=================================================
    // BLT - Branch if Less Then
    static func execBLT(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        branch(<, rs1, rs2, imm12, mstate)
    }

    //=================================================
    // BGE - Branch if Greater or Equal
    static func execBGE(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        branch(>=, rs1, rs2, imm12, mstate)
    }

    //=================================================
    // BLTU - Branch if Less Then (Unsigned)
    static func execBLTU(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let x1 = mstate.getRegister(rs1)
        let x2 = mstate.getRegister(rs2)
        let branchCheck =
            mstate.xlenIsRV32
                ? (UInt32(truncatingIfNeeded: x1) < UInt32(truncatingIfNeeded: x2))
                : (UInt64(bitPattern: x1) < UInt64(bitPattern: x2))
        if branchCheck {
            let newPC = mstate.PC &+ Int64(imm12)
            if newPC % mstate.instrAlign != 0 {
                return mstate.setRunState(.Trap(.BreakAddress))
            } else if newPC == mstate.PC {
                return mstate.setRunState(.Stopped)
            } else {
                return mstate.setPC(newPC)
            }
        } else {
            return mstate.incPC()
        }
    }

    //=================================================
    // BGEU - Branch If Greater or Equal (Unsigned)
    static func execBGEU(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let x1 = mstate.getRegister(rs1)
        let x2 = mstate.getRegister(rs2)
        let branchCheck =
            mstate.xlenIsRV32
                ? (UInt32(truncatingIfNeeded: x1) >= UInt32(truncatingIfNeeded: x2))
                : (UInt64(bitPattern: x1) >= UInt64(bitPattern: x2))
        if branchCheck {
            let newPC = mstate.PC &+ Int64(imm12)
            if newPC % mstate.instrAlign != 0 {
                return mstate.setRunState(.Trap(.BreakAddress))
            } else if newPC == mstate.PC {
                return mstate.setRunState(.Stopped)
            } else {
                return mstate.setPC(newPC)
            }
        } else {
            return mstate.incPC()
        }
    }

    //=================================================
    // LB - Load Byte from Memory
    static func execLB(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        guard let memResult = mstate.loadMemoryByte(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        return mstate.setRegisterIncPC(rd, Int64(memResult))
    }

    //=================================================
    // LH - Load Half-word (2 bytes)  from Memory
    static func execLH(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        guard let memResult = mstate.loadMemoryHalfWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        return mstate.setRegisterIncPC(rd, Int64(memResult))
    }

    //=================================================
    // LW - Load Word (4 bytes) from Memory
    static func execLW(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        guard let memResult = mstate.loadMemoryWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        return mstate.setRegisterIncPC(rd, Int64(memResult))
    }

    //=================================================
    // LBU - Load Byte Unsigned from Memory
    static func execLBU(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        guard let memResult = mstate.loadMemoryByte(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let memVal = UInt8(bitPattern: memResult)
        return mstate.setRegisterIncPC(rd, Int64(memVal))
    }

    //=================================================
    // LHU - Load Half-word (2 bytes) Unsigned from Memory
    static func execLHU(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        guard let memResult = mstate.loadMemoryHalfWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let memVal = UInt16(bitPattern: memResult)
        return mstate.setRegisterIncPC(rd, Int64(memVal))
    }

    //=================================================
    // SB - Store Byte to Memory
    static func execSB(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        let rs2Val = mstate.getRegister(rs2)
        return mstate.storeMemoryByteIncPC(addr, rs2Val)
    }

    //=================================================
    // SH - Store 2 Bytes (Hald word) to Memory
    static func execSH(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        let rs2Val = mstate.getRegister(rs2)
        return mstate.storeMemoryHalfWordIncPC(addr, rs2Val)
    }

    //=================================================
    // SW - Store 4 Bytes (Word) to Memory
    static func execSW(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        let rs2Val = mstate.getRegister(rs2)
        return mstate.storeMemoryWordIncPC(addr, rs2Val)
    }

    //=================================================
    // ADDI - Add immediate
    static func execADDI(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) &+ Int64(imm12)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SLTI - Set to 1 if Less Then Immediate
    static func execSLTI(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64 = mstate.getRegister(rs1) < Int64(imm12) ? 1 : 0
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SLTIU - Set to 1 if Less Then Unsign Immediate
    static func execSLTIU(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64 =
            mstate.xlenIsRV32
                ? (UInt32(truncatingIfNeeded: mstate.getRegister(rs1)) < UInt32(bitPattern: imm12) ? 1 : 0)
                : (UInt64(bitPattern: mstate.getRegister(rs1)) < UInt64(bitPattern: Int64(imm12)) ? 1 : 0)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // XORI - Xor immediately
    static func execXORI(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) ^ Int64(imm12)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // ORI - Or immediately
    static func execORI(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) | Int64(imm12)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SLLI - Shift Left Logical Immediate
    static func execSLLI(_ rd: Register, _ rs1: Register, _ shamt: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) << Int64(shamt)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SRLI - Shift Right Logical Immediate
    static func execSRLI(_ rd: Register, _ rs1: Register, _ shamt: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64 =
            mstate.xlenIsRV32
                ? (Int64(UInt32(truncatingIfNeeded: mstate.getRegister(rs1)) >> UInt32(shamt)))
                : (Int64(bitPattern: UInt64(bitPattern: mstate.getRegister(rs1)) >> UInt64(shamt)))
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SRAI - Shift Right Arithmetic Immediate
    static func execSRAI(_ rd: Register, _ rs1: Register, _ shamt: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) >> Int64(shamt)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // ANDI - And immediately
    static func execANDI(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) & Int64(imm12)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // ADD - Add operation
    static func execADD(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) &+ mstate.getRegister(rs2)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SUB - Sub operation
    static func execSUB(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) &- mstate.getRegister(rs2)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SLL - Shift Logical Left
    // SLL, SRL, and SRA perform logical left, logical right, and arithmetic right shifts on the value in register
    // rs1 by the shift amount held in register rs2. In RV32I, only the low 5 bits of rs2 are considered for the
    // shift amount. In RV64I, only the low 6 bits of rs2 are considered for the shift amount.
    static func execSLL(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64
        if mstate.xlenIsRV32 {
            let shamt = mstate.getRegister(rs2) & 0x1f
            rdVal = Int64(Int32(bitPattern: UInt32(truncatingIfNeeded: mstate.getRegister(rs1)) << UInt32(shamt)))
        } else {
            let shamt = mstate.getRegister(rs2) & 0x3f
            rdVal = mstate.getRegister(rs1) << shamt
        }
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SLT - Set 1 if Less Then
    static func execSLT(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64 = mstate.getRegister(rs1) < mstate.getRegister(rs2) ? 1 : 0
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SLTU - Set to 1 if Less Then Unsign Immediate
    static func execSLTU(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64 =
            mstate.xlenIsRV32
                ? (UInt32(truncatingIfNeeded: mstate.getRegister(rs1)) < UInt32(truncatingIfNeeded: mstate.getRegister(rs2)) ? 1 : 0)
                : (UInt64(bitPattern: mstate.getRegister(rs1)) < UInt64(bitPattern: mstate.getRegister(rs2)) ? 1 : 0)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // XOR - Xor operation
    static func execXOR(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) ^ mstate.getRegister(rs2)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SRL - Shift Right Logical
    // SLL, SRL, and SRA perform logical left, logical right, and arithmetic right shifts on the value in register
    // rs1 by the shift amount held in register rs2. In RV32I, only the low 5 bits of rs2 are considered for the
    // shift amount. In RV64I, only the low 6 bits of rs2 are considered for the shift amount.
    static func execSRL(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64
        if mstate.xlenIsRV32 {
            let shamt = mstate.getRegister(rs2) & 0x1f
            rdVal = Int64(Int32(bitPattern: UInt32(truncatingIfNeeded: mstate.getRegister(rs1)) >> UInt32(shamt)))
        } else {
            let shamt = mstate.getRegister(rs2) & 0x3f
            rdVal = Int64(bitPattern: UInt64(bitPattern: mstate.getRegister(rs1)) >> UInt64(shamt))
        }
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // SRA - Shift Right Arithmetic
    // SLL, SRL, and SRA perform logical left, logical right, and arithmetic right shifts on the value in register
    // rs1 by the shift amount held in register rs2. In RV32I, only the low 5 bits of rs2 are considered for the
    // shift amount. In RV64I, only the low 6 bits of rs2 are considered for the shift amount.
    static func execSRA(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal: Int64
        if mstate.xlenIsRV32 {
            let shamt = mstate.getRegister(rs2) & 0x1f
            rdVal = Int64(Int32(truncatingIfNeeded: mstate.getRegister(rs1)) >> Int32(shamt))
        } else {
            let shamt = mstate.getRegister(rs2) & 0x3f
            rdVal = mstate.getRegister(rs1) >> shamt
        }
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // OR - Or operation
    static func execOR(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) | mstate.getRegister(rs2)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // AND - And operation
    static func execAND(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) & mstate.getRegister(rs2)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // Fence - Fence operation (no operations)
    static func execFENCE(_ mstate: consuming MachineState) -> MachineState {
        mstate.incPC()
    }

    //=================================================
    // ECALL - ECALL operation
    static func execECALL(_ mstate: consuming MachineState) -> MachineState {
        mstate.setRunState(.Trap(.ECall))
    }

    //=================================================
    // execEBREAK - EBREAK operation
    static func execEBREAK(_ mstate: consuming MachineState) -> MachineState {
        mstate.setRunState(.Trap(.EBreak))
    }

    /// Execute I-instructions
    public static func Execute(_ instr: InstructionI, _ mstate: consuming MachineState) -> MachineState {
        switch instr {
        case let .LUI(rd, imm20):
            execLUI(rd, imm20, mstate)
        case let .AUIPC(rd, imm20):
            execAUIPC(rd, imm20, mstate)
        case let .JALR(rd, rs1, imm12):
            execJALR(rd, rs1, imm12, mstate)
        case let .JAL(rd, imm20):
            execJAL(rd, imm20, mstate)
        case let .BEQ(rs1, rs2, imm12):
            execBEQ(rs1, rs2, imm12, mstate)
        case let .BNE(rs1, rs2, imm12):
            execBNE(rs1, rs2, imm12, mstate)
        case let .BLT(rs1, rs2, imm12):
            execBLT(rs1, rs2, imm12, mstate)
        case let .BGE(rs1, rs2, imm12):
            execBGE(rs1, rs2, imm12, mstate)
        case let .BLTU(rs1, rs2, imm12):
            execBLTU(rs1, rs2, imm12, mstate)
        case let .BGEU(rs1, rs2, imm12):
            execBGEU(rs1, rs2, imm12, mstate)
        case let .LB(rd, rs1, imm12):
            execLB(rd, rs1, imm12, mstate)
        case let .LH(rd, rs1, imm12):
            execLH(rd, rs1, imm12, mstate)
        case let .LW(rd, rs1, imm12):
            execLW(rd, rs1, imm12, mstate)
        case let .LBU(rd, rs1, imm12):
            execLBU(rd, rs1, imm12, mstate)
        case let .LHU(rd, rs1, imm12):
            execLHU(rd, rs1, imm12, mstate)
        case let .SB(rs1, rs2, imm12):
            execSB(rs1, rs2, imm12, mstate)
        case let .SH(rs1, rs2, imm12):
            execSH(rs1, rs2, imm12, mstate)
        case let .SW(rs1, rs2, imm12):
            execSW(rs1, rs2, imm12, mstate)
        case let .ADDI(rd, rs1, imm12):
            execADDI(rd, rs1, imm12, mstate)
        case let .SLTI(rd, rs1, imm12):
            execSLTI(rd, rs1, imm12, mstate)
        case let .SLTIU(rd, rs1, imm12):
            execSLTIU(rd, rs1, imm12, mstate)
        case let .XORI(rd, rs1, imm12):
            execXORI(rd, rs1, imm12, mstate)
        case let .ORI(rd, rs1, imm12):
            execORI(rd, rs1, imm12, mstate)
        case let .ANDI(rd, rs1, imm12):
            execANDI(rd, rs1, imm12, mstate)
        case let .SLLI(rd, rs1, shamt):
            execSLLI(rd, rs1, shamt, mstate)
        case let .SRLI(rd, rs1, shamt):
            execSRLI(rd, rs1, shamt, mstate)
        case let .SRAI(rd, rs1, shamt):
            execSRAI(rd, rs1, shamt, mstate)
        case let .ADD(rd, rs1, rs2):
            execADD(rd, rs1, rs2, mstate)
        case let .SUB(rd, rs1, rs2):
            execSUB(rd, rs1, rs2, mstate)
        case let .SLL(rd, rs1, rs2):
            execSLL(rd, rs1, rs2, mstate)
        case let .SLT(rd, rs1, rs2):
            execSLT(rd, rs1, rs2, mstate)
        case let .SLTU(rd, rs1, rs2):
            execSLTU(rd, rs1, rs2, mstate)
        case let .XOR(rd, rs1, rs2):
            execXOR(rd, rs1, rs2, mstate)
        case let .SRL(rd, rs1, rs2):
            execSRL(rd, rs1, rs2, mstate)
        case let .SRA(rd, rs1, rs2):
            execSRA(rd, rs1, rs2, mstate)
        case let .OR(rd, rs1, rs2):
            execOR(rd, rs1, rs2, mstate)
        case let .AND(rd, rs1, rs2):
            execAND(rd, rs1, rs2, mstate)
        case .FENCE:
            execFENCE(mstate)
        case .ECALL:
            execECALL(mstate)
        case .EBREAK:
            execEBREAK(mstate)
        case .None:
            mstate.setRunState(.Trap(.InstructionExecute))
        }
    }
}
