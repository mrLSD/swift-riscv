// Replica of riscv-fs `ExecuteM.fs` (module ISA.RISCV.Execute.M)
//
// .NET integer arithmetic wraps silently; the Swift replica uses the overflow
// operators (&*, &+, &-) and bit-pattern conversions to reproduce that bit-for-bit.
// The trapping cases of Swift's `/` and `%` (division by zero, Int64.min / -1) are
// unreachable: the RISC-V special cases are checked first, exactly as the reference does.

public enum ExecuteM {
    /// High 64 bits of the unsigned 128-bit product, computed with 32-bit limbs
    /// (the reference's algorithm, verbatim).
    static func mulhu(_ x: UInt64, _ y: UInt64) -> UInt64 {
        let x0 = UInt64(UInt32(truncatingIfNeeded: x))
        let y0 = UInt64(UInt32(truncatingIfNeeded: y))
        let x1 = x >> 32
        let y1 = y >> 32

        var t = x1 &* y0 &+ ((x0 &* y0) >> 32)
        let y2 = UInt64(UInt32(truncatingIfNeeded: t))
        let y3 = t >> 32
        let y4 = x0 &* y1 &+ y2
        t = x1 &* y1 &+ y3 &+ (y4 >> 32)
        let y5 = UInt64(UInt32(truncatingIfNeeded: t))
        let y6 = (t >> 32) << 32
        return y6 | y5
    }

    /// High 64 bits of the signed 128-bit product.
    static func mulh(_ x: Int64, _ y: Int64) -> Int64 {
        let neg = (x < 0) != (y < 0)
        let x1 = UInt64(bitPattern: x < 0 ? 0 &- x : x)
        let y1 = UInt64(bitPattern: y < 0 ? 0 &- y : y)
        let res = mulhu(x1, y1)
        let resd: Int64 = x &* y == 0 ? 1 : 0
        return neg ? Int64(bitPattern: ~res) &+ resd : Int64(bitPattern: res)
    }

    /// High 64 bits of the signed x unsigned 128-bit product.
    static func mulhsu(_ x: Int64, _ y: UInt64) -> Int64 {
        let neg = x < 0
        let x1 = UInt64(bitPattern: x < 0 ? 0 &- x : x)
        let res = mulhu(x1, y)
        let resd: Int64 = x &* Int64(bitPattern: y) == 0 ? 1 : 0
        return neg ? Int64(bitPattern: ~res) &+ resd : Int64(bitPattern: res)
    }

    //=================================================
    // MUL - Multiplication operation - sign * sign
    static func execMUL(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rdVal = mstate.getRegister(rs1) &* mstate.getRegister(rs2)
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // MULH - Multiplication operation - sign * sign and return high 32 bits
    static func execMULH(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let hRes: Int64 =
            mstate.xlenIsRV32
                ? (mstate.getRegister(rs1) &* mstate.getRegister(rs2)).bitSlice(63, 32)
                : mulh(mstate.getRegister(rs1), mstate.getRegister(rs2))
        return mstate.setRegisterIncPC(rd, hRes)
    }

    //=================================================
    // MULHSU - Multiplication operation - Multiplication operation - sign * unsign and return high 32 bits
    static func execMULHSU(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let hRes: Int64 =
            mstate.xlenIsRV32
                ? (rs1Val &* Int64(UInt32(truncatingIfNeeded: rs2Val))).bitSlice(63, 32)
                : mulhsu(rs1Val, UInt64(bitPattern: rs2Val))
        return mstate.setRegisterIncPC(rd, hRes)
    }

    //=================================================
    // MULHU - Multiplication operation - Multiplication operation - unsign * unsign and return high 32 bits
    static func execMULHU(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let hRes: Int64 =
            mstate.xlenIsRV32
                ? (Int64(UInt32(truncatingIfNeeded: rs1Val)) &* Int64(UInt32(truncatingIfNeeded: rs2Val))).bitSlice(63, 32)
                : Int64(bitPattern: mulhu(UInt64(bitPattern: rs1Val), UInt64(bitPattern: rs2Val)))
        return mstate.setRegisterIncPC(rd, hRes)
    }

    //=================================================
    // DIV - Division operation
    static func execDIV(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let minSigned: Int64 = mstate.xlenIsRV32 ? -2147483648 : Int64.min
        let rdVal: Int64 =
            if rs2Val == 0 {
                -1
            } else if rs1Val == minSigned && rs2Val == -1 {
                rs1Val
            } else {
                rs1Val / rs2Val
            }
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // DIVU - Division unsign operation
    static func execDIVU(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal: Int64 =
            mstate.xlenIsRV32
                ? rs2Val == 0
                    ? 0xFFFFFFFF
                    : Int64(UInt32(truncatingIfNeeded: rs1Val) / UInt32(truncatingIfNeeded: rs2Val))
                : rs2Val == 0
                    ? Int64(bitPattern: 0xFFFF_FFFF_FFFF_FFFF)
                    : Int64(bitPattern: UInt64(bitPattern: rs1Val) / UInt64(bitPattern: rs2Val))
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // REM - Rem operation
    static func execREM(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let minSigned: Int64 = mstate.xlenIsRV32 ? -2147483648 : Int64.min
        let rdVal: Int64 =
            if rs2Val == 0 {
                rs1Val
            } else if rs1Val == minSigned && rs2Val == -1 {
                0
            } else {
                rs1Val % rs2Val
            }
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    //=================================================
    // REMU - Rem unsign operation
    static func execREMU(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let rs1Val = mstate.getRegister(rs1)
        let rs2Val = mstate.getRegister(rs2)
        let rdVal: Int64 =
            mstate.xlenIsRV32
                ? rs2Val == 0
                    ? rs1Val
                    : Int64(UInt32(truncatingIfNeeded: rs1Val) % UInt32(truncatingIfNeeded: rs2Val))
                : rs2Val == 0
                    ? rs1Val
                    : Int64(bitPattern: UInt64(bitPattern: rs1Val) % UInt64(bitPattern: rs2Val))
        return mstate.setRegisterIncPC(rd, rdVal)
    }

    /// Execute M-instructions
    public static func Execute(_ instr: InstructionM, _ mstate: consuming MachineState) -> MachineState {
        switch instr {
        case let .MUL(rd, rs1, rs2):
            execMUL(rd, rs1, rs2, mstate)
        case let .MULH(rd, rs1, rs2):
            execMULH(rd, rs1, rs2, mstate)
        case let .MULHSU(rd, rs1, rs2):
            execMULHSU(rd, rs1, rs2, mstate)
        case let .MULHU(rd, rs1, rs2):
            execMULHU(rd, rs1, rs2, mstate)
        case let .DIV(rd, rs1, rs2):
            execDIV(rd, rs1, rs2, mstate)
        case let .DIVU(rd, rs1, rs2):
            execDIVU(rd, rs1, rs2, mstate)
        case let .REM(rd, rs1, rs2):
            execREM(rd, rs1, rs2, mstate)
        case let .REMU(rd, rs1, rs2):
            execREMU(rd, rs1, rs2, mstate)
        case .None:
            mstate.setRunState(.Trap(.InstructionExecute))
        }
    }
}
