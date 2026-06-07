// Replica of riscv-fs `ExecuteA64.fs` (module ISA.RISCV.Execute.A64)
//
// Double-word atomics on RV64. Single-hart simulator: LR/SC are plain
// load/store plus reservation bookkeeping; AMOs are load + op + store.
// .NET arithmetic wraps silently — replicated with &+.

public enum ExecuteA64 {
    //=================================================
    // LR.D - Load-Reserved Double Word operation
    // This acts just like a lw in this implementation (no need for sync)
    // (except there's no immediate)
    static func execLR_D(_ rd: Register, _ rs1: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        return mstate.setRegisterReserveIncPC(rd, memResult, addr, 8)
    }

    //=================================================
    // SC.D - Store Conditional Double Word
    // This acts just like a sd in this implementation, but it will
    // always set the check register to 0 (indicating load success)
    static func execSC_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        if mstate.Reservation?.0 == addr && mstate.Reservation?.1 == 8 {
            let mstate = mstate.storeMemoryDoubleWord(addr, mstate.getRegister(rs2))
            return mstate.setRegisterClearReservationIncPC(rd, 0)
        } else {
            return mstate.setRegisterClearReservationIncPC(rd, 1)
        }
    }

    //=================================================
    // AMOSWAP.D - AMO Swap Double word
    static func execAMOSWAP_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = rs2Val
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOADD.D - AMO Add Double Word
    static func execAMOADD_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = memResult &+ rs2Val
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOXOR.D - AMO Xor Double Word
    static func execAMOXOR_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = memResult ^ rs2Val
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOAND.D - AMO And Double Word
    static func execAMOAND_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = memResult & rs2Val
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOOR.D - AMO Or Double Word
    static func execAMOOR_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = memResult | rs2Val
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOMIN.D - AMO Min Double Word
    static func execAMOMIN_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = memResult > rs2Val ? rs2Val : memResult
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOMAX.D - AMO Max Double Word
    static func execAMOMAX_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = memResult < rs2Val ? rs2Val : memResult
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOMINU.D - AMO Unsigned Min Double Word
    static func execAMOMINU_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = UInt64(bitPattern: memResult) > UInt64(bitPattern: rs2Val) ? rs2Val : memResult
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    //=================================================
    // AMOMAXU.D - AMO Unsigned Max Double Word
    static func execAMOMAXU_D(_ rd: Register, _ rs1: Register, _ rs2: Register, _ mstate: consuming MachineState) -> MachineState {
        let addr = mstate.alignByArchUnsign(mstate.getRegister(rs1))
        let rs2Val = mstate.getRegister(rs2)

        guard let memResult = mstate.loadMemoryDoubleWord(addr) else {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        let resMemOp = UInt64(bitPattern: memResult) < UInt64(bitPattern: rs2Val) ? rs2Val : memResult
        return mstate.storeBytesSetRegisterIncPC(8, addr, resMemOp, rd, memResult)
    }

    /// Execute A64-instructions
    public static func Execute(_ instr: InstructionA64, _ mstate: consuming MachineState) -> MachineState {
        // Atomics require an 8-byte-aligned address; check before dispatch.
        let rawAddr: Int64 =
            switch instr {
            case let .LR_D(_, rs1, _, _):
                mstate.getRegister(rs1)
            case let .SC_D(_, rs1, _, _, _), let .AMOSWAP_D(_, rs1, _, _, _),
                 let .AMOADD_D(_, rs1, _, _, _), let .AMOXOR_D(_, rs1, _, _, _),
                 let .AMOAND_D(_, rs1, _, _, _), let .AMOOR_D(_, rs1, _, _, _),
                 let .AMOMIN_D(_, rs1, _, _, _), let .AMOMAX_D(_, rs1, _, _, _),
                 let .AMOMINU_D(_, rs1, _, _, _), let .AMOMAXU_D(_, rs1, _, _, _):
                mstate.getRegister(rs1)
            case .None:
                0
            }
        let addr = mstate.alignByArchUnsign(rawAddr)
        if instr != InstructionA64.None && addr % 8 != 0 {
            return mstate.setRunState(.Trap(.MemAddress(addr)))
        }
        switch instr {
        case let .LR_D(rd, rs1, _, _):
            return execLR_D(rd, rs1, mstate)
        case let .SC_D(rd, rs1, rs2, _, _):
            return execSC_D(rd, rs1, rs2, mstate)
        case let .AMOSWAP_D(rd, rs1, rs2, _, _):
            return execAMOSWAP_D(rd, rs1, rs2, mstate)
        case let .AMOADD_D(rd, rs1, rs2, _, _):
            return execAMOADD_D(rd, rs1, rs2, mstate)
        case let .AMOXOR_D(rd, rs1, rs2, _, _):
            return execAMOXOR_D(rd, rs1, rs2, mstate)
        case let .AMOAND_D(rd, rs1, rs2, _, _):
            return execAMOAND_D(rd, rs1, rs2, mstate)
        case let .AMOOR_D(rd, rs1, rs2, _, _):
            return execAMOOR_D(rd, rs1, rs2, mstate)
        case let .AMOMIN_D(rd, rs1, rs2, _, _):
            return execAMOMIN_D(rd, rs1, rs2, mstate)
        case let .AMOMAX_D(rd, rs1, rs2, _, _):
            return execAMOMAX_D(rd, rs1, rs2, mstate)
        case let .AMOMINU_D(rd, rs1, rs2, _, _):
            return execAMOMINU_D(rd, rs1, rs2, mstate)
        case let .AMOMAXU_D(rd, rs1, rs2, _, _):
            return execAMOMAXU_D(rd, rs1, rs2, mstate)
        case .None:
            return mstate.setRunState(.Trap(.InstructionExecute))
        }
    }
}
