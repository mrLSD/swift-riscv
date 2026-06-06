// Subset of riscv-fs `ExecuteI64.fs` (module ISA.RISCV.Execute.I64)
//
// Only the execution semantics the C extension delegates to are ported
// (C.LD/C.LDSP -> execLD, C.SD/C.SDSP -> execSD, C.ADDIW -> execADDIW,
// C.ADDW -> execADDW, C.SUBW -> execSUBW). The I64 decoder itself
// (LWU/LD/SD/ADDIW/SLLIW/... as 32-bit encodings) is not ported yet.
// Word ops compute in 32 bits (wrapping, like .NET Int32) and sign-extend
// the 32-bit result to 64.

public enum ExecuteI64 {
    //=================================================
    // LD - Load double Word (8 bytes) from Memory
    static func execLD(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        return mstate.setRegisterIncPC(rd, memResult)
    }

    //=================================================
    // SD - Store double Word (8 bytes) to Memory
    static func execSD(_ rs1: Register, _ rs2: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1) &+ Int64(imm12))
        let rs2Val = mstate.getRegister(rs2)
        return mstate.storeMemoryDoubleWordIncPC(addr, rs2Val)
    }

    //=================================================
    // ADDIW - Add immediate Word
    // Returns sign-extension to 64 bits of lower 32 bits of result.
    static func execADDIW(_ rd: Register, _ rs1: Register, _ imm12: InstrField, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = Int32(truncatingIfNeeded: mstate.getRegister(rs1)) &+ imm12
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    //=================================================
    // ADDW - Add operation Word
    // Returns sign-extension to 64 bits of lower 32 bits of result.
    static func execADDW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = Int32(truncatingIfNeeded: mstate.getRegister(rs1)) &+ Int32(truncatingIfNeeded: mstate.getRegister(rs2))
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    //=================================================
    // SUBW - Sub operation Word
    // Returns sign-extension to 64 bits of lower 32 bits of result.
    static func execSUBW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = Int32(truncatingIfNeeded: mstate.getRegister(rs1)) &- Int32(truncatingIfNeeded: mstate.getRegister(rs2))
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }
}
