// Replica of riscv-fs `ExecuteC.fs` (module ISA.RISCV.Execute.C)

// Execute C-instructions: each compressed op delegates to the base instruction
// it expands to. PC advances by InstrLen (= 2 for compressed), so link addresses
// and branch/jump targets are correct through the shared base semantics.
public enum ExecuteC {
    public static func Execute(_ instr: InstructionC, _ mstate: consuming MachineState) -> MachineState {
        switch instr {
        case let .C_ADDI4SPN(rd, imm): return ExecuteI.execADDI(rd, 2, imm, mstate)
        case let .C_LW(rd, rs1, imm): return ExecuteI.execLW(rd, rs1, imm, mstate)
        case let .C_LD(rd, rs1, imm): return ExecuteI64.execLD(rd, rs1, imm, mstate)
        case let .C_SW(rs1, rs2, imm): return ExecuteI.execSW(rs1, rs2, imm, mstate)
        case let .C_SD(rs1, rs2, imm): return ExecuteI64.execSD(rs1, rs2, imm, mstate)
        case let .C_ADDI(rd, imm): return ExecuteI.execADDI(rd, rd, imm, mstate)
        case let .C_ADDIW(rd, imm): return ExecuteI64.execADDIW(rd, rd, imm, mstate)
        case let .C_LI(rd, imm): return ExecuteI.execADDI(rd, 0, imm, mstate)
        case let .C_LUI(rd, imm): return ExecuteI.execLUI(rd, imm, mstate)
        case let .C_ADDI16SP(imm): return ExecuteI.execADDI(2, 2, imm, mstate)
        case let .C_SRLI(rd, shamt): return ExecuteI.execSRLI(rd, rd, shamt, mstate)
        case let .C_SRAI(rd, shamt): return ExecuteI.execSRAI(rd, rd, shamt, mstate)
        case let .C_ANDI(rd, imm): return ExecuteI.execANDI(rd, rd, imm, mstate)
        case let .C_SUB(rd, rs2): return ExecuteI.execSUB(rd, rd, rs2, mstate)
        case let .C_XOR(rd, rs2): return ExecuteI.execXOR(rd, rd, rs2, mstate)
        case let .C_OR(rd, rs2): return ExecuteI.execOR(rd, rd, rs2, mstate)
        case let .C_AND(rd, rs2): return ExecuteI.execAND(rd, rd, rs2, mstate)
        case let .C_SUBW(rd, rs2): return ExecuteI64.execSUBW(rd, rd, rs2, mstate)
        case let .C_ADDW(rd, rs2): return ExecuteI64.execADDW(rd, rd, rs2, mstate)
        case let .C_J(imm): return ExecuteI.execJAL(0, imm, mstate)
        case let .C_JAL(imm): return ExecuteI.execJAL(1, imm, mstate)
        case let .C_BEQZ(rs1, imm): return ExecuteI.execBEQ(rs1, 0, imm, mstate)
        case let .C_BNEZ(rs1, imm): return ExecuteI.execBNE(rs1, 0, imm, mstate)
        case let .C_SLLI(rd, shamt): return ExecuteI.execSLLI(rd, rd, shamt, mstate)
        case let .C_LWSP(rd, imm): return ExecuteI.execLW(rd, 2, imm, mstate)
        case let .C_LDSP(rd, imm): return ExecuteI64.execLD(rd, 2, imm, mstate)
        case let .C_JR(rs1): return ExecuteI.execJALR(0, rs1, 0, mstate)
        case let .C_JALR(rs1): return ExecuteI.execJALR(1, rs1, 0, mstate)
        case let .C_MV(rd, rs2): return ExecuteI.execADD(rd, 0, rs2, mstate)
        case let .C_ADD(rd, rs2): return ExecuteI.execADD(rd, rd, rs2, mstate)
        case .C_EBREAK: return ExecuteI.execEBREAK(mstate)
        case let .C_SWSP(rs2, imm): return ExecuteI.execSW(2, rs2, imm, mstate)
        case let .C_SDSP(rs2, imm): return ExecuteI64.execSD(2, rs2, imm, mstate)
        case .None: return mstate.setRunState(.Trap(.InstructionExecute))
        }
    }
}
