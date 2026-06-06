// Replica of riscv-fs `ExecuteM64.fs` (module ISA.RISCV.Execute.M64)
//
// Word (32-bit) multiply/divide on RV64: operands are the low 32 bits of the
// registers; the 32-bit result is sign-extended to 64. .NET Int32 arithmetic
// wraps silently — replicated with &* and bit-pattern conversions. Swift's
// trapping `/` and `%` cases (zero divisor, Int32.min / -1) are unreachable:
// the RISC-V special cases are checked first, exactly as the reference does.

public enum ExecuteM64 {
    //=================================================
    // MULW - Multiplication Word operation - sign * sign
    static func execMULW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = Int32(truncatingIfNeeded: mstate.getRegister(rs1)) &* Int32(truncatingIfNeeded: mstate.getRegister(rs2))
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    //=================================================
    // DIVW - Division Word operation - sign * sign
    static func execDIVW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = Int32(truncatingIfNeeded: mstate.getRegister(rs1))
        let rs2Val = Int32(truncatingIfNeeded: mstate.getRegister(rs2))
        let minSigned = Int32.min
        let rdVal: Int32 =
            if rs2Val == 0 {
                -1
            } else if rs1Val == minSigned && rs2Val == -1 {
                rs1Val
            } else {
                rs1Val / rs2Val
            }
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    //=================================================
    // DIVUW - Division Unsign Word operation - sign * sign
    static func execDIVUW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = UInt32(truncatingIfNeeded: mstate.getRegister(rs1))
        let rs2Val = UInt32(truncatingIfNeeded: mstate.getRegister(rs2))
        let rdVal: Int32 =
            if rs2Val == 0 {
                -1
            } else {
                Int32(bitPattern: rs1Val / rs2Val)
            }
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    //=================================================
    // REMW - Division Unsign Word operation - sign * sign
    static func execREMW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = Int32(truncatingIfNeeded: mstate.getRegister(rs1))
        let rs2Val = Int32(truncatingIfNeeded: mstate.getRegister(rs2))
        let minSigned = Int32.min
        let rdVal: Int32 =
            if rs2Val == 0 {
                rs1Val
            } else if rs1Val == minSigned && rs2Val == -1 {
                0
            } else {
                rs1Val % rs2Val
            }
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    //=================================================
    // REMUW - Division Unsign Word operation - sign * sign
    static func execREMUW(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = UInt32(truncatingIfNeeded: mstate.getRegister(rs1))
        let rs2Val = UInt32(truncatingIfNeeded: mstate.getRegister(rs2))
        let rdVal: Int32 =
            if rs2Val == 0 {
                Int32(bitPattern: rs1Val)
            } else {
                Int32(bitPattern: rs1Val % rs2Val)
            }
        return mstate.setRegisterIncPC(rd, Int64(rdVal))
    }

    /// Execute M64-instructions
    public static func Execute(_ instr: InstructionM64, _ mstate: consuming MachineState) -> MachineState {
        switch instr {
        case let .MULW(rd, rs1, rs2):
            execMULW(rd, rs1, rs2, mstate)
        case let .DIVW(rd, rs1, rs2):
            execDIVW(rd, rs1, rs2, mstate)
        case let .DIVUW(rd, rs1, rs2):
            execDIVUW(rd, rs1, rs2, mstate)
        case let .REMW(rd, rs1, rs2):
            execREMW(rd, rs1, rs2, mstate)
        case let .REMUW(rd, rs1, rs2):
            execREMUW(rd, rs1, rs2, mstate)
        case .None:
            mstate.setRunState(.Trap(.InstructionExecute))
        }
    }
}
